# PRD v1.0.3

## 原始核心需求

1、后端的user用户表，增加字段： 用户是否正在徒步（用户点击开始徒步进入徒步状态时设置为true，用户点击结束徒步时设置为false，用户手动退出了app时也设置为false，默认为false），用户徒步中当前经纬度（当用户是否正在徒步的值为true时，每次前端用户的经纬度改变时，更新后端这个字段到最新经纬度值） 

2、用户的 隐私设置 页面的几个配置值（见图片），也要存在后端的user用户表中。 

3、当用户A点击了开始徒步进入徒步页面并定位获得位置后，更新用户A的经纬度位置到后端，并以这个经纬度位置的值，在用户表中寻找到所有的满足了以下要求的用户B们的经纬度位置：用户B和用户A的经纬度位置相差值distance在10公里以内，而且用户B隐私设置中设置的可见范围值大于等于distance的值。那么就把满足条件的所有这些用户B们的位置用圆圈和头像图片标记在用户A的徒步地图上，样式和用户A的头像圆圈样式一样（只把圆圈的颜色变为粉色）。 

4、在用户徒步过程中，每10秒进行一次 上面的 “3这一点”，并刷新显示用户A周围的用户B们的头像显示的位置。

---

## 一、数据库设计

### 1.1 用户表扩展（users）

```sql
-- 新增字段
ALTER TABLE users ADD COLUMN is_hiking BOOLEAN DEFAULT FALSE COMMENT '是否正在徒步';
ALTER TABLE users ADD COLUMN current_lat DECIMAL(10, 8) NULL COMMENT '当前纬度';
ALTER TABLE users ADD COLUMN current_lng DECIMAL(11, 8) NULL COMMENT '当前经度';
ALTER TABLE users ADD COLUMN location_updated_at BIGINT NULL COMMENT '位置更新时间戳';

-- 隐私设置字段（对应图片中的配置）
ALTER TABLE users ADD COLUMN visible_on_map BOOLEAN DEFAULT TRUE COMMENT '在地图上显示我的位置';
ALTER TABLE users ADD COLUMN visible_range INT DEFAULT 5 COMMENT '可见范围（公里）：1,3,5,10';
ALTER TABLE users ADD COLUMN receive_sos BOOLEAN DEFAULT TRUE COMMENT '接收求救信息';
ALTER TABLE users ADD COLUMN receive_questions BOOLEAN DEFAULT TRUE COMMENT '接收周围提问';
ALTER TABLE users ADD COLUMN receive_feedback BOOLEAN DEFAULT TRUE COMMENT '接收路况反馈';

-- 索引优化
CREATE INDEX idx_is_hiking ON users(is_hiking);
CREATE INDEX idx_location ON users(current_lat, current_lng);
CREATE INDEX idx_hiking_location ON users(is_hiking, current_lat, current_lng);
```

**完整用户表结构**：
```sql
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY,
    nickname VARCHAR(50) NOT NULL,
    avatar VARCHAR(500),
    phone VARCHAR(20),
    wechat_openid VARCHAR(50),
    
    -- 徒步状态
    is_hiking BOOLEAN DEFAULT FALSE,
    current_lat DECIMAL(10, 8),
    current_lng DECIMAL(11, 8),
    location_updated_at BIGINT,
    
    -- 隐私设置
    visible_on_map BOOLEAN DEFAULT TRUE,
    visible_range INT DEFAULT 5,
    receive_sos BOOLEAN DEFAULT TRUE,
    receive_questions BOOLEAN DEFAULT TRUE,
    receive_feedback BOOLEAN DEFAULT TRUE,
    
    -- 基础字段
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_is_hiking (is_hiking),
    INDEX idx_location (current_lat, current_lng),
    INDEX idx_hiking_location (is_hiking, current_lat, current_lng)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 二、后端API设计

### 2.1 位置更新接口

```typescript
// POST /api/users/location
// 前端每10秒调用，或位置显著变化时调用

interface UpdateLocationRequest {
  lat: number;        // 纬度
  lng: number;        // 经度
  accuracy?: number;  // 精度（米）
  altitude?: number;  // 海拔（可选）
}

interface UpdateLocationResponse {
  success: boolean;
  nearbyUsers: NearbyUser[]; // 直接返回周围用户，减少请求次数
}

// 后端处理逻辑
async function updateLocation(req: UpdateLocationRequest, userId: string) {
  // 1. 更新用户位置
  await db.query(`
    UPDATE users 
    SET current_lat = ?, 
        current_lng = ?, 
        location_updated_at = ?,
        is_hiking = true
    WHERE id = ?
  `, [req.lat, req.lng, Date.now(), userId]);
  
  // 2. 查询周围用户（使用Haversine公式计算距离）
  const nearbyUsers = await findNearbyUsers(req.lat, req.lng, userId);
  
  return { success: true, nearbyUsers };
}

// 核心查询：寻找周围可见的用户
async function findNearbyUsers(
  centerLat: number, 
  centerLng: number, 
  excludeUserId: string,
  maxDistance: number = 10 // 最大搜索10公里
): Promise<NearbyUser[]> {
  
  // Haversine公式计算距离（单位：公里）
  const query = `
    SELECT 
      u.id,
      u.nickname,
      u.avatar,
      u.current_lat as lat,
      u.current_lng as lng,
      u.visible_range,
      -- 计算距离
      (6371 * acos(
        cos(radians(?)) * cos(radians(u.current_lat)) * 
        cos(radians(u.current_lng) - radians(?)) + 
        sin(radians(?)) * sin(radians(u.current_lat))
      )) AS distance
    FROM users u
    WHERE u.id != ?
      AND u.is_hiking = true
      AND u.visible_on_map = true
      AND u.current_lat IS NOT NULL
      AND u.current_lng IS NOT NULL
      -- 距离在10公里内
      HAVING distance <= ?
      -- 对方的可见范围要大于等于实际距离（对方允许我看到他）
      AND distance <= u.visible_range
    ORDER BY distance ASC
  `;
  
  const results = await db.query(query, [
    centerLat, centerLng, centerLat,  // Haversine参数
    excludeUserId,                     // 排除自己
    maxDistance                        // 最大距离限制
  ]);
  
  return results.map(row => ({
    id: row.id,
    nickname: row.nickname,
    avatar: row.avatar,
    lat: row.lat,
    lng: row.lng,
    distance: parseFloat(row.distance.toFixed(2)), // 保留2位小数
    visibleRange: row.visible_range
  }));
}
```

### 2.2 徒步状态管理接口

```typescript
// POST /api/hiking/start
// 开始徒步时调用
interface StartHikingRequest {
  lat: number;
  lng: number;
  startTime: number;
}

// 后端处理：设置is_hiking=true，初始化位置
async function startHiking(userId: string, data: StartHikingRequest) {
  await db.query(`
    UPDATE users 
    SET is_hiking = true,
        current_lat = ?,
        current_lng = ?,
        location_updated_at = ?
    WHERE id = ?
  `, [data.lat, data.lng, data.startTime, userId]);
  
  // 创建徒步记录（返回hikeId）
  const hikeId = await createHikingRecord(userId, data);
  
  return { hikeId, success: true };
}

// POST /api/hiking/end
// 结束徒步时调用
interface EndHikingRequest {
  hikeId: string;
  endTime: number;
  finalLat: number;
  finalLng: number;
}

// 后端处理：设置is_hiking=false，清空位置
async function endHiking(userId: string, data: EndHikingRequest) {
  // 更新用户状态
  await db.query(`
    UPDATE users 
    SET is_hiking = false,
        current_lat = NULL,
        current_lng = NULL,
        location_updated_at = NULL
    WHERE id = ?
  `, [userId]);
  
  // 完成徒步记录
  await finalizeHikingRecord(data.hikeId, data);
  
  return { success: true };
}

// POST /api/hiking/pause
// 暂停徒步（可选，位置更新频率降低）
async function pauseHiking(userId: string) {
  // 标记暂停状态，但保持is_hiking=true
  await db.query(`
    UPDATE users 
    SET is_paused = true
    WHERE id = ?
  `, [userId]);
}

// WebSocket或心跳检测：用户异常断开时清理状态
async function cleanupOfflineUsers() {
  const timeout = 5 * 60 * 1000; // 5分钟无更新视为离线
  
  await db.query(`
    UPDATE users 
    SET is_hiking = false,
        current_lat = NULL,
        current_lng = NULL
    WHERE is_hiking = true 
      AND location_updated_at < ?
  `, [Date.now() - timeout]);
}
```

### 2.3 隐私设置接口

```typescript
// GET /api/users/privacy-settings
// 获取当前用户的隐私设置
interface PrivacySettingsResponse {
  visibleOnMap: boolean;
  visibleRange: number; // 1,3,5,10
  receiveSOS: boolean;
  receiveQuestions: boolean;
  receiveFeedback: boolean;
}

// PUT /api/users/privacy-settings
// 更新隐私设置
interface UpdatePrivacyRequest {
  visibleOnMap?: boolean;
  visibleRange?: number;
  receiveSOS?: boolean;
  receiveQuestions?: boolean;
  receiveFeedback?: boolean;
}

// 后端直接更新对应字段
async function updatePrivacySettings(userId: string, settings: UpdatePrivacyRequest) {
  const updates = [];
  const values = [];
  
  if (settings.visibleOnMap !== undefined) {
    updates.push('visible_on_map = ?');
    values.push(settings.visibleOnMap);
  }
  if (settings.visibleRange !== undefined) {
    updates.push('visible_range = ?');
    values.push(settings.visibleRange);
  }
  // ... 其他字段
  
  values.push(userId);
  
  await db.query(`
    UPDATE users SET ${updates.join(', ')} WHERE id = ?
  `, values);
  
  return { success: true };
}
```

---

## 三、前端实现

### 3.1 位置更新管理器

```typescript
// services/LocationManager.ts
class LocationManager {
  private updateInterval: NodeJS.Timeout | null = null;
  private readonly UPDATE_INTERVAL = 10000; // 10秒
  private lastLocation: {lat: number; lng: number} | null = null;
  
  // 开始徒步时调用
  async startHiking() {
    // 1. 获取初始位置
    const location = await this.getCurrentPosition();
    this.lastLocation = location;
    
    // 2. 通知后端开始徒步
    const { hikeId } = await api.post('/hiking/start', {
      lat: location.lat,
      lng: location.lng,
      startTime: Date.now()
    });
    
    // 3. 启动定时更新
    this.startLocationUpdates();
    
    return hikeId;
  }
  
  // 启动定时位置更新
  private startLocationUpdates() {
    // 立即执行第一次
    this.updateLocation();
    
    // 每10秒更新
    this.updateInterval = setInterval(() => {
      this.updateLocation();
    }, this.UPDATE_INTERVAL);
  }
  
  // 单次位置更新
  private async updateLocation() {
    try {
      const location = await this.getCurrentPosition();
      
      // 距离过滤：如果移动小于10米，跳过更新（减少请求）
      if (this.lastLocation && 
          this.calculateDistance(location, this.lastLocation) < 0.01) {
        return;
      }
      
      this.lastLocation = location;
      
      // 调用后端API，同时获取周围用户
      const { nearbyUsers } = await api.post('/users/location', {
        lat: location.lat,
        lng: location.lng,
        accuracy: location.accuracy,
        altitude: location.altitude
      });
      
      // 触发事件，通知地图组件更新
      eventEmitter.emit('nearbyUsersUpdated', nearbyUsers);
      
    } catch (error) {
      console.error('位置更新失败:', error);
    }
  }
  
  // 获取当前位置（封装高德/系统API）
  private async getCurrentPosition(): Promise<Location> {
    return new Promise((resolve, reject) => {
      // 优先使用高德定位
      AMap.plugin('AMap.Geolocation', () => {
        const geolocation = new AMap.Geolocation({
          enableHighAccuracy: true,
          timeout: 10000,
          showButton: false
        });
        
        geolocation.getCurrentPosition((status, result) => {
          if (status === 'complete') {
            resolve({
              lat: result.position.lat,
              lng: result.position.lng,
              accuracy: result.accuracy,
              altitude: result.altitude
            });
          } else {
            reject(new Error('定位失败'));
          }
        });
      });
    });
  }
  
  // 计算两点距离（公里）
  private calculateDistance(p1: Location, p2: Location): number {
    const R = 6371; // 地球半径
    const dLat = this.toRad(p2.lat - p1.lat);
    const dLng = this.toRad(p2.lng - p1.lng);
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(this.toRad(p1.lat)) * Math.cos(this.toRad(p2.lat)) *
              Math.sin(dLng/2) * Math.sin(dLng/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }
  
  private toRad(deg: number): number {
    return deg * Math.PI / 180;
  }
  
  // 结束徒步
  async endHiking(hikeId: string) {
    // 停止定时器
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }
    
    const location = this.lastLocation || await this.getCurrentPosition();
    
    // 通知后端
    await api.post('/hiking/end', {
      hikeId,
      endTime: Date.now(),
      finalLat: location.lat,
      finalLng: location.lng
    });
    
    this.lastLocation = null;
  }
  
  // 应用退出时清理（通过AppState监听）
  async handleAppExit() {
    if (this.updateInterval) {
      // 通知后端用户离线
      await api.post('/users/offline');
    }
  }
}
```

### 3.2 地图组件 - 周围用户标记

```typescript
// components/HikingMap.tsx
interface HikingMapProps {
  userLocation: {lat: number; lng: number};
  nearbyUsers: NearbyUser[];
}

const HikingMap: React.FC<HikingMapProps> = ({ userLocation, nearbyUsers }) => {
  const mapRef = useRef<AMap.Map>(null);
  
  // 监听周围用户更新
  useEffect(() => {
    const handleNearbyUsers = (users: NearbyUser[]) => {
      updateNearbyUserMarkers(users);
    };
    
    eventEmitter.on('nearbyUsersUpdated', handleNearbyUsers);
    return () => {
      eventEmitter.off('nearbyUsersUpdated', handleNearbyUsers);
    };
  }, []);
  
  // 更新周围用户标记
  const updateNearbyUserMarkers = (users: NearbyUser[]) => {
    if (!mapRef.current) return;
    
    // 清除旧标记
    mapRef.current.clearMap();
    
    // 重新添加所有标记
    
    // 1. 自己的位置（蓝色）
    addSelfMarker(userLocation);
    
    // 2. 周围用户（粉色圆圈+头像）
    users.forEach(user => {
      addNearbyUserMarker(user);
    });
  };
  
  // 添加周围用户标记
  const addNearbyUserMarker = (user: NearbyUser) => {
    const marker = new AMap.Marker({
      position: [user.lng, user.lat],
      offset: new AMap.Pixel(-20, -20), // 居中
      content: createMarkerContent(user), // 自定义HTML
      zIndex: 100
    });
    
    // 点击事件
    marker.on('click', () => {
      showUserActionSheet(user);
    });
    
    mapRef.current?.add(marker);
  };
  
  // 创建标记HTML内容
  const createMarkerContent = (user: NearbyUser): string => {
    return `
      <div style="
        position: relative;
        width: 40px;
        height: 40px;
        display: flex;
        align-items: center;
        justify-content: center;
      ">
        <!-- 粉色外圈 -->
        <div style="
          position: absolute;
          width: 40px;
          height: 40px;
          border-radius: 50%;
          border: 3px solid #E91E63;
          background: rgba(233, 30, 99, 0.1);
          box-shadow: 0 2px 8px rgba(233, 30, 99, 0.3);
        "></div>
        
        <!-- 头像 -->
        <img 
          src="${user.avatar || '/default-avatar.png'}" 
          style="
            width: 32px;
            height: 32px;
            border-radius: 50%;
            object-fit: cover;
            border: 2px solid white;
          "
          onerror="this.src='/default-avatar.png'"
        />
        
        <!-- 距离标签 -->
        <div style="
          position: absolute;
          bottom: -18px;
          left: 50%;
          transform: translateX(-50%);
          background: #E91E63;
          color: white;
          padding: 2px 6px;
          border-radius: 10px;
          font-size: 10px;
          white-space: nowrap;
          box-shadow: 0 1px 3px rgba(0,0,0,0.2);
        ">
          ${user.distance < 1 
            ? Math.round(user.distance * 1000) + 'm' 
            : user.distance.toFixed(1) + 'km'
          }
        </div>
      </div>
    `;
  };
  
  return (
    <View style={styles.container}>
      <div ref={mapContainerRef} style={styles.map} />
      
      {/* 周围用户列表（底部浮动面板） */}
      <NearbyUsersPanel users={nearbyUsers} />
    </View>
  );
};

// 周围用户列表面板
const NearbyUsersPanel: React.FC<{users: NearbyUser[]}> = ({ users }) => {
  const [expanded, setExpanded] = useState(false);
  
  if (users.length === 0) {
    return (
      <View style={styles.emptyPanel}>
        <Text style={styles.emptyText}>周围暂无其他徒步者</Text>
      </View>
    );
  }
  
  return (
    <View style={[styles.panel, expanded && styles.panelExpanded]}>
      <TouchableOpacity 
        style={styles.panelHeader}
        onPress={() => setExpanded(!expanded)}
      >
        <Text style={styles.panelTitle}>
          周围 {users.length} 位徒步者
        </Text>
        <Icon name={expanded ? 'chevron.down' : 'chevron.up'} />
      </TouchableOpacity>
      
      {expanded && (
        <ScrollView style={styles.userList}>
          {users.map(user => (
            <UserListItem key={user.id} user={user} />
          ))}
        </ScrollView>
      )}
    </View>
  );
};

const UserListItem: React.FC<{user: NearbyUser}> = ({ user }) => {
  return (
    <TouchableOpacity style={styles.userItem}>
      <View style={styles.avatarContainer}>
        <Image source={{uri: user.avatar}} style={styles.avatar} />
        <View style={styles.pinkRing} />
      </View>
      
      <View style={styles.userInfo}>
        <Text style={styles.nickname}>{user.nickname || '徒步者'}</Text>
        <Text style={styles.distance}>
          距离 {user.distance < 1 
            ? Math.round(user.distance * 1000) + '米' 
            : user.distance.toFixed(1) + '公里'
          }
        </Text>
      </View>
      
      <View style={styles.actions}>
        <TouchableOpacity style={styles.actionBtn}>
          <Icon name="questionmark.bubble" size={20} color="#2196F3" />
        </TouchableOpacity>
        <TouchableOpacity style={styles.actionBtn}>
          <Icon name="location.fill" size={20} color="#4CAF50" />
        </TouchableOpacity>
      </View>
    </TouchableOpacity>
  );
};
```

### 3.3 样式定义

```typescript
const styles = StyleSheet.create({
  container: {
    flex: 1,
    position: 'relative',
  },
  map: {
    width: '100%',
    height: '100%',
  },
  
  // 面板样式
  panel: {
    position: 'absolute',
    bottom: 160, // 避开底部控制栏
    left: 16,
    right: 16,
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 5,
    maxHeight: 60, // 折叠状态
  },
  panelExpanded: {
    maxHeight: 300,
  },
  panelHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  panelTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212121',
  },
  
  // 用户列表项
  userList: {
    marginTop: 12,
  },
  userItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#F5F5F5',
  },
  avatarContainer: {
    width: 44,
    height: 44,
    position: 'relative',
    marginRight: 12,
  },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    position: 'absolute',
    top: 4,
    left: 4,
  },
  pinkRing: {
    position: 'absolute',
    width: 44,
    height: 44,
    borderRadius: 22,
    borderWidth: 2,
    borderColor: '#E91E63',
    backgroundColor: 'rgba(233, 30, 99, 0.08)',
  },
  userInfo: {
    flex: 1,
  },
  nickname: {
    fontSize: 15,
    fontWeight: '500',
    color: '#212121',
  },
  distance: {
    fontSize: 12,
    color: '#757575',
    marginTop: 2,
  },
  actions: {
    flexDirection: 'row',
    gap: 8,
  },
  actionBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#F5F5F5',
    alignItems: 'center',
    justifyContent: 'center',
  },
  
  // 空状态
  emptyPanel: {
    position: 'absolute',
    bottom: 160,
    left: 16,
    right: 16,
    backgroundColor: 'rgba(255,255,255,0.9)',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 14,
    color: '#757575',
  },
});
```

---

## 四、隐私设置页面（对接后端）

### 4.1 页面实现

```typescript
// pages/PrivacySettings.tsx
const PrivacySettingsPage: React.FC = () => {
  const [settings, setSettings] = useState<PrivacySettings | null>(null);
  const [loading, setLoading] = useState(true);
  
  // 加载设置
  useEffect(() => {
    loadSettings();
  }, []);
  
  const loadSettings = async () => {
    const data = await api.get('/users/privacy-settings');
    setSettings(data);
    setLoading(false);
  };
  
  // 更新单个设置
  const updateSetting = async (key: keyof PrivacySettings, value: any) => {
    // 乐观更新UI
    setSettings(prev => ({ ...prev, [key]: value }));
    
    // 同步到后端
    try {
      await api.put('/users/privacy-settings', { [key]: value });
    } catch (error) {
      // 失败回滚
      loadSettings();
      showToast('设置保存失败');
    }
  };
  
  if (loading) return <LoadingView />;
  
  return (
    <ScrollView style={styles.container}>
      {/* 位置可见性 */}
      <Section title="位置可见性">
        <SettingItem
          title="在地图上显示我的位置"
          subtitle="关闭后其他人无法在地图上看到您"
          type="switch"
          value={settings.visibleOnMap}
          onChange={(v) => updateSetting('visibleOnMap', v)}
        />
        
        {settings.visibleOnMap && (
          <>
            <SettingItem
              title="可见范围"
              subtitle={`当前设置：${settings.visibleRange}公里`}
              type="custom"
            >
              <RangeSlider
                value={settings.visibleRange}
                options={[1, 3, 5, 10]}
                onChange={(v) => updateSetting('visibleRange', v)}
              />
            </SettingItem>
            
            {/* 范围可视化预览 */}
            <RangePreview range={settings.visibleRange} />
          </>
        )}
      </Section>
      
      {/* 接收设置 */}
      <Section title="接收设置">
        <SettingItem
          title="接收求救信息"
          subtitle="附近有用户求救时通知我（强烈建议开启）"
          icon="sos"
          iconColor="#D32F2F"
          type="switch"
          value={settings.receiveSOS}
          onChange={(v) => updateSetting('receiveSOS', v)}
        />
        
        <SettingItem
          title="接收周围提问"
          subtitle="允许路线相似的用户向我提问"
          icon="questionmark.bubble"
          iconColor="#2196F3"
          type="switch"
          value={settings.receiveQuestions}
          onChange={(v) => updateSetting('receiveQuestions', v)}
        />
        
        <SettingItem
          title="接收路况反馈"
          subtitle="接收前方路况信息"
          icon="exclamationmark.triangle"
          iconColor="#FF9800"
          type="switch"
          value={settings.receiveFeedback}
          onChange={(v) => updateSetting('receiveFeedback', v)}
        />
      </Section>
    </ScrollView>
  );
};

// 范围滑块组件（对应图片中的样式）
const RangeSlider: React.FC<{
  value: number;
  options: number[];
  onChange: (value: number) => void;
}> = ({ value, options, onChange }) => {
  const currentIndex = options.indexOf(value);
  
  return (
    <View style={sliderStyles.container}>
      <View style={sliderStyles.track}>
        {/* 已选中的绿色部分 */}
        <View 
          style={[
            sliderStyles.activeTrack,
            { width: `${((currentIndex) / (options.length - 1)) * 100}%` }
          ]} 
        />
        
        {/* 刻度点 */}
        {options.map((opt, index) => (
          <TouchableOpacity
            key={opt}
            style={[
              sliderStyles.dot,
              index <= currentIndex && sliderStyles.activeDot
            ]}
            onPress={() => onChange(opt)}
          />
        ))}
        
        {/* 滑块 */}
        <View 
          style={[
            sliderStyles.thumb,
            { left: `${(currentIndex / (options.length - 1)) * 100}%` }
          ]}
        />
      </View>
      
      <View style={sliderStyles.labels}>
        {options.map(opt => (
          <Text 
            key={opt} 
            style={[
              sliderStyles.label,
              value === opt && sliderStyles.activeLabel
            ]}
          >
            {opt}公里
          </Text>
        ))}
      </View>
    </View>
  );
};

const sliderStyles = StyleSheet.create({
  container: {
    paddingVertical: 16,
  },
  track: {
    height: 4,
    backgroundColor: '#E0E0E0',
    borderRadius: 2,
    position: 'relative',
    marginHorizontal: 8,
  },
  activeTrack: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    backgroundColor: '#4CAF50',
    borderRadius: 2,
  },
  dot: {
    position: 'absolute',
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#E0E0E0',
    top: -2,
    transform: [{ translateX: -4 }],
  },
  activeDot: {
    backgroundColor: '#4CAF50',
  },
  thumb: {
    position: 'absolute',
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#4CAF50',
    top: -10,
    marginLeft: -12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 4,
  },
  labels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 12,
    paddingHorizontal: 4,
  },
  label: {
    fontSize: 12,
    color: '#757575',
  },
  activeLabel: {
    color: '#4CAF50',
    fontWeight: '600',
  },
});
```

---

## 五、生命周期与异常处理

### 5.1 应用状态监听

```typescript
// 监听App前后台状态，处理异常退出
import { AppState } from 'react-native';

class AppLifecycleManager {
  private appStateSubscription: any;
  
  init() {
    this.appStateSubscription = AppState.addEventListener(
      'change', 
      this.handleAppStateChange
    );
  }
  
  private handleAppStateChange = async (nextAppState: string) => {
    const currentUser = getCurrentUser();
    if (!currentUser) return;
    
    if (nextAppState === 'background' || nextAppState === 'inactive') {
      // 应用进入后台，启动心跳保持
      this.startBackgroundHeartbeat();
    } else if (nextAppState === 'active') {
      // 应用回到前台，恢复正常更新
      this.stopBackgroundHeartbeat();
      
      // 检查当前徒步状态
      const status = await api.get('/users/hiking-status');
      if (status.isHiking && !locationManager.isRunning()) {
        // 恢复位置更新
        locationManager.resume();
      }
    }
  };
  
  // 后台心跳（防止被系统杀死，保持is_hiking状态）
  private heartbeatInterval: NodeJS.Timeout | null = null;
  
  private startBackgroundHeartbeat() {
    // 每30秒发送一次心跳，更新location_updated_at
    this.heartbeatInterval = setInterval(async () => {
      try {
        await api.post('/users/heartbeat');
      } catch (e) {
        // 心跳失败，可能已离线
      }
    }, 30000);
  }
  
  private stopBackgroundHeartbeat() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }
  
  // 应用真正退出时（通过Native模块监听）
  async handleAppTerminate() {
    // 通知后端清理状态
    await api.post('/users/offline', { reason: 'app_terminate' });
  }
}
```

### 5.2 后端心跳接口

```typescript
// POST /api/users/heartbeat
// 前端每30秒调用一次（后台运行时）

async function heartbeat(userId: string) {
  await db.query(`
    UPDATE users 
    SET location_updated_at = ?
    WHERE id = ? AND is_hiking = true
  `, [Date.now(), userId]);
  
  return { success: true };
}

// 后端定时任务：清理超时用户（每5分钟运行）
setInterval(async () => {
  const timeout = 2 * 60 * 1000; // 2分钟无心跳视为离线
  
  await db.query(`
    UPDATE users 
    SET is_hiking = false,
        current_lat = NULL,
        current_lng = NULL
    WHERE is_hiking = true 
      AND location_updated_at < ?
  `, [Date.now() - timeout]);
  
  console.log('清理离线徒步用户完成');
}, 5 * 60 * 1000);
```

---

## 六、性能优化

### 6.1 前端优化

```typescript
// 1. 位置更新节流：移动小于10米不更新
// 2. 地图标记池复用，避免频繁创建DOM
// 3. 用户列表虚拟滚动（如果周围用户很多）

// 标记池管理
class MarkerPool {
  private pool: Map<string, AMap.Marker> = new Map();
  
  getOrCreate(userId: string): AMap.Marker {
    if (!this.pool.has(userId)) {
      const marker = new AMap.Marker();
      this.pool.set(userId, marker);
    }
    return this.pool.get(userId)!;
  }
  
  updatePosition(userId: string, lat: number, lng: number) {
    const marker = this.getOrCreate(userId);
    marker.setPosition([lng, lat]);
  }
  
  // 清理不再可见的用户标记
  cleanup(visibleUserIds: string[]) {
    for (const [id, marker] of this.pool) {
      if (!visibleUserIds.includes(id)) {
        marker.setMap(null);
        this.pool.delete(id);
      }
    }
  }
}
```

---

## 七、接口汇总

| 接口                          | 方法 | 描述                          | 调用时机        |
| ----------------------------- | ---- | ----------------------------- | --------------- |
| `/api/hiking/start`           | POST | 开始徒步，设置is_hiking=true  | 点击开始徒步    |
| `/api/hiking/end`             | POST | 结束徒步，设置is_hiking=false | 点击结束确认    |
| `/api/users/location`         | POST | 更新位置，返回周围用户        | 每10秒/位置变化 |
| `/api/users/heartbeat`        | POST | 后台心跳保活                  | 每30秒（后台）  |
| `/api/users/offline`          | POST | 应用退出清理                  | 应用退出        |
| `/api/users/privacy-settings` | GET  | 获取隐私设置                  | 进入设置页      |
| `/api/users/privacy-settings` | PUT  | 更新隐私设置                  | 修改设置时      |

---

