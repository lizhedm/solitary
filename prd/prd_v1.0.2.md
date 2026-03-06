# PRD v1.0.2

## 实时数据统计、历史记录持久化与轨迹回放

---

### 原始核心需求：

1、开始徒步后，在上方的GPS和徒步时长的一栏中，右边增加显示三个数据 公里数（icon+数字，比如 0.3km），消耗热量（icon+数字，比如20千卡），海拔爬升（icon+数字，比如500米）。公里数调用高德地图接口获得。消耗热量使用公式计算获得：能量消耗（千卡）= 5.5 × 60 × 时间(小时)。海拔爬升需要记录点击开始徒步时的海拔高度和当前的海拔高度的差值（可能需要调用手机的相关传感器函数来获得） 

2、点击结束按钮并确认结束后，将本次徒步的数据存储到“徒步历史”页面中，将现有前端页面中的模拟假数据去掉，增加本次徒步的真实数据的卡片到“徒步历史”页面中。并将本次数据存储到后端的数据库的hiking_records表中（相应需要有值的字段都要对接好）。前端从后端的hiking_records表中获得当前用户的真实历史徒步数据并展示出来。“徒步历史”页面的统计栏中的“本月徒步”改为“累计次数”（统计真实的该用户总的历史徒步次数）、“本月距离”改为“总距离”（统计真实的该用户总的历史徒步公里数）、“累计次数”改为“累计海拔爬升”（统计真实的该用户总的历史徒步海拔爬升总数）。同时将本次徒步的高德地图的线路图截图生成一张图片存储到后端（后面徒步历史的轨迹地图回放需要展示） 

3、历史徒步的详情页面“徒步详情”，也需要展示该次历史徒步数据的真实数据。在“轨迹地图回放”这一部分，展示该次徒步历史的高德地图的截图图片



## 一、实时数据统计模块（地图页顶部栏）

### 1.1 顶部栏布局重构

**视觉结构**：
```
┌─────────────────────────────────────────────────────────────┐
│  [GPS状态]          [计时器]            [数据统计区]          │
│  🛰️ GPS良好      00:12:45        🏃 0.3km  🔥 20千卡  ⛰️ 500m │
│                                                             │
│  左侧固定宽度(80pt)   中间自适应       右侧自适应(剩余空间)      │
└─────────────────────────────────────────────────────────────┘
```

**组件详细定义**：
```typescript
interface TopBarStats {
  distance: number;        // 公里，保留1位小数
  calories: number;        // 千卡，整数
  elevationGain: number;   // 米，整数（当前海拔 - 起始海拔）
}

// 顶部栏完整组件
<TopInfoBar>
  <LeftSection>
    <GPSIndicator 
      status={gpsStatus} 
      accuracy={locationAccuracy} 
    />
  </LeftSection>
  
  <CenterSection>
    <TimerDisplay 
      value={formatDuration(timerDuration)}
      label="徒步时长"
      isRunning={timerState === 'RUNNING'}
    />
  </CenterSection>
  
  <RightSection>
    <StatsGroup>
      <StatItem 
        icon="figure.walk"  // SF Symbols: 跑步人形
        value={`${stats.distance.toFixed(1)}km`}
        label="距离"
        color="#2E7D32"
      />
      <StatItem 
        icon="flame.fill"
        value={`${stats.calories}千卡`}
        label="热量"
        color="#FF5722"
      />
      <StatItem 
        icon="mountain.2.fill"
        value={`${stats.elevationGain}m`}
        label="爬升"
        color="#795548"
      />
    </StatsGroup>
  </RightSection>
</TopInfoBar>
```

### 1.2 数据统计计算逻辑

#### 1.2.1 公里数计算（高德地图）

```typescript
// 使用高德地图SDK计算实际行走距离
class DistanceCalculator {
  private coordinates: Array<{lat: number; lng: number}> = [];
  
  addCoordinate(coord: {lat: number; lng: number}) {
    this.coordinates.push(coord);
    return this.calculateTotalDistance();
  }
  
  calculateTotalDistance(): number {
    if (this.coordinates.length < 2) return 0;
    
    let totalDistance = 0;
    
    for (let i = 1; i < this.coordinates.length; i++) {
      const prev = this.coordinates[i - 1];
      const curr = this.coordinates[i];
      
      // 使用高德地图距离计算API
      const segmentDistance = AMap.GeometryUtil.distance(
        [prev.lng, prev.lat],
        [curr.lng, curr.lat]
      );
      
      totalDistance += segmentDistance;
    }
    
    return totalDistance / 1000; // 转换为公里
  }
  
  // 或使用高德轨迹纠偏接口（更精确，考虑道路吸附）
  async calculateWithRoadCorrection(): Promise<number> {
    const path = this.coordinates.map(c => `${c.lng},${c.lat}`).join(';');
    
    const response = await fetch(
      `https://restapi.amap.com/v3/grasproad/driving?` +
      `key=${AMAP_KEY}&` +
      `points=${path}`
    );
    
    const data = await response.json();
    return data.data.distance / 1000; // 公里
  }
}

// React Hook封装
function useHikingStats(coordinates: Coordinate[], durationMs: number) {
  const [stats, setStats] = useState<TopBarStats>({
    distance: 0,
    calories: 0,
    elevationGain: 0
  });
  
  useEffect(() => {
    // 距离计算
    const distance = calculateDistance(coordinates);
    
    // 热量计算：5.5 × 60 × 时间(小时)
    const hours = durationMs / (1000 * 60 * 60);
    const calories = Math.round(5.5 * 60 * hours);
    
    // 海拔爬升计算
    const elevationGain = calculateElevationGain(coordinates);
    
    setStats({ distance, calories, elevationGain });
  }, [coordinates, durationMs]);
  
  return stats;
}
```

#### 1.2.2 热量计算公式

```typescript
/**
 * 热量计算公式
 * 能量消耗（千卡）= 5.5 × 60 × 时间(小时)
 * 
 * 5.5 METs (Metabolic Equivalent of Task) - 徒步运动代谢当量
 * 60 - 标准体重60kg的基准值
 * 
 * 实际实现中可根据用户体重调整：
 * 能量消耗 = 5.5 × 体重(kg) × 时间(小时)
 */
function calculateCalories(durationMs: number, userWeight: number = 60): number {
  const hours = durationMs / (1000 * 60 * 60);
  return Math.round(5.5 * userWeight * hours);
}
```

#### 1.2.3 海拔爬升计算（传感器融合）

```typescript
interface ElevationData {
  currentAltitude: number;      // 当前海拔
  startAltitude: number;        // 起始海拔
  gain: number;                 // 累计爬升（只计算上升，不计算下降）
  maxAltitude: number;          // 最高海拔
  minAltitude: number;          // 最低海拔
}

class ElevationTracker {
  private startAltitude: number | null = null;
  private maxAltitude: number = -Infinity;
  private minAltitude: number = Infinity;
  private totalGain: number = 0;
  private lastAltitude: number | null = null;
  
  // 初始化，记录起始海拔
  initialize(initialAltitude: number) {
    this.startAltitude = initialAltitude;
    this.lastAltitude = initialAltitude;
    this.maxAltitude = initialAltitude;
    this.minAltitude = initialAltitude;
  }
  
  // 更新海拔数据
  updateAltitude(altitude: number) {
    if (this.startAltitude === null) {
      this.initialize(altitude);
      return;
    }
    
    // 更新极值
    this.maxAltitude = Math.max(this.maxAltitude, altitude);
    this.minAltitude = Math.min(this.minAltitude, altitude);
    
    // 计算爬升（只累加上升部分，过滤小幅波动）
    if (this.lastAltitude !== null) {
      const diff = altitude - this.lastAltitude;
      if (diff > 0.5) { // 过滤0.5米以内的噪声
        this.totalGain += diff;
      }
    }
    
    this.lastAltitude = altitude;
  }
  
  getCurrentGain(): number {
    return Math.round(this.totalGain);
  }
  
  getStats(): ElevationData {
    return {
      currentAltitude: this.lastAltitude || 0,
      startAltitude: this.startAltitude || 0,
      gain: Math.round(this.totalGain),
      maxAltitude: Math.round(this.maxAltitude),
      minAltitude: Math.round(this.minAltitude)
    };
  }
}

// 获取海拔的多种方式（优先级排序）
async function getCurrentAltitude(): Promise<number> {
  // 方式1：GPS海拔（所有设备支持，精度较低 ±10-50m）
  const gpsAltitude = await getGPSAltitude();
  
  // 方式2：气压计（iPhone 6+/Android带气压计设备，精度高 ±1m）
  if (isBarometerAvailable()) {
    const barometerAltitude = await getBarometerAltitude();
    // 使用卡尔曼滤波融合GPS和气压计数据
    return fuseAltitudes(gpsAltitude, barometerAltitude);
  }
  
  // 方式3：高德地图海拔API（基于地形数据）
  const { lat, lng } = await getCurrentLocation();
  const amapElevation = await fetchAMapElevation(lat, lng);
  
  return gpsAltitude || amapElevation || 0;
}

// 高德海拔API
async function fetchAMapElevation(lat: number, lng: number): Promise<number> {
  const response = await fetch(
    `https://restapi.amap.com/v3/elevation/point?` +
    `key=${AMAP_KEY}&` +
    `location=${lng},${lat}`
  );
  const data = await response.json();
  return data.elevation || 0;
}
```

**实时更新频率**：
- 距离：每收到一个新的GPS坐标点立即更新
- 热量：每秒更新（基于持续时间）
- 海拔：每5秒更新一次（或气压计有显著变化时）

---

## 二、历史记录持久化与展示

### 2.1 数据库表结构（hiking_records）

```sql
CREATE TABLE hiking_records (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    
    -- 时间信息
    start_time BIGINT NOT NULL,
    end_time BIGINT NOT NULL,
    duration_ms BIGINT NOT NULL,           -- 实际运动时长（扣除暂停）
    total_pause_ms BIGINT DEFAULT 0,       -- 总暂停时长
    
    -- 路线数据（存储为压缩JSON或单独文件）
    coordinates_json TEXT,                 -- 坐标点数组JSON
    compressed_route TEXT,                 -- 简化后的路线（用于地图回放）
    
    -- 核心统计数据
    distance_km DECIMAL(8,2) NOT NULL,     -- 总距离（公里）
    calories_kcal INT NOT NULL,            -- 消耗热量（千卡）
    elevation_gain_m INT NOT NULL,         -- 海拔爬升（米）
    max_altitude_m INT,                    -- 最高海拔
    min_altitude_m INT,                    -- 最低海拔
    
    -- 位置信息
    start_location_name VARCHAR(100),      -- 起点地名
    end_location_name VARCHAR(100),        -- 终点地名
    start_lat DECIMAL(10,8) NOT NULL,
    start_lng DECIMAL(11,8) NOT NULL,
    end_lat DECIMAL(10,8) NOT NULL,
    end_lng DECIMAL(11,8) NOT NULL,
    
    -- 地图截图
    map_snapshot_url VARCHAR(500),         -- 高德地图轨迹截图URL
    
    -- 统计计数
    coordinate_count INT,                  -- 轨迹点数量
    message_count INT DEFAULT 0,           -- 本次消息数
    participant_count INT DEFAULT 0,       -- 参与对话人数
    
    -- 元数据
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_user_id (user_id),
    INDEX idx_start_time (start_time),
    INDEX idx_user_time (user_id, start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2.2 结束徒步时的数据保存流程

```typescript
interface HikingFinalData {
  // 基础信息
  id: string;
  userId: string;
  startTime: number;
  endTime: number;
  duration: number;
  totalPauseTime: number;
  
  // 统计数据
  distance: number;           // 公里
  calories: number;           // 千卡
  elevationGain: number;      // 米
  maxAltitude: number;
  minAltitude: number;
  
  // 路线数据
  coordinates: Coordinate[];
  
  // 位置信息
  startLocation: { name: string; lat: number; lng: number };
  endLocation: { name: string; lat: number; lng: number };
}

async function finalizeHiking(): Promise<void> {
  // 1. 停止所有服务
  await stopLocationTracking();
  const finalTimerState = getTimerState();
  
  // 2. 构建最终数据对象
  const hikingData: HikingFinalData = {
    id: generateUUID(),
    userId: getCurrentUser().id,
    startTime: hikeStartTime,
    endTime: Date.now(),
    duration: finalTimerState.totalDuration,
    totalPauseTime: finalTimerState.totalPauseTime,
    distance: distanceCalculator.getTotal(),
    calories: calculateCalories(finalTimerState.totalDuration),
    elevationGain: elevationTracker.getCurrentGain(),
    maxAltitude: elevationTracker.getStats().maxAltitude,
    minAltitude: elevationTracker.getStats().minAltitude,
    coordinates: getAllCoordinates(),
    startLocation: {
      name: await reverseGeocode(coordinates[0]),
      ...coordinates[0]
    },
    endLocation: {
      name: await reverseGeocode(coordinates[coordinates.length - 1]),
      ...coordinates[coordinates.length - 1]
    }
  };
  
  // 3. 生成地图截图
  showLoading('正在生成轨迹图...');
  const mapSnapshot = await generateMapSnapshot(hikingData.coordinates);
  const snapshotUrl = await uploadImage(mapSnapshot);
  hikingData.mapSnapshotUrl = snapshotUrl;
  
  // 4. 保存到后端
  showLoading('正在保存记录...');
  await api.post('/hiking-records', {
    ...hikingData,
    coordinates: compressCoordinates(hikingData.coordinates) // 压缩后上传
  });
  
  // 5. 更新本地状态
  addToLocalHistory(hikingData);
  
  // 6. 跳转
  hideLoading();
  navigate('/hiking/history', { 
    highlight: hikingData.id,
    showSuccessToast: true 
  });
}

// 地图截图生成（高德地图静态图API）
async function generateMapSnapshot(coordinates: Coordinate[]): Promise<Blob> {
  if (coordinates.length < 2) return null;
  
  // 构建路径参数
  const path = coordinates.map(c => `${c.lng},${c.lat}`).join(';');
  
  // 计算地图视野
  const bounds = calculateBounds(coordinates);
  const center = {
    lng: (bounds.minLng + bounds.maxLng) / 2,
    lat: (bounds.minLat + bounds.maxLat) / 2
  };
  
  // 高德静态地图API
  const url = `https://restapi.amap.com/v3/staticmap?` +
    `key=${AMAP_KEY}&` +
    `size=800*600&` +
    `zoom=auto&` +
    `paths=2,0x2E7D32,3,,:${path}&` +  // 绿色轨迹线
    `markers=mid,0x4CAF50,A:${coordinates[0].lng},${coordinates[0].lat}|` + // 起点
    `mid,0xD32F2F,B:${coordinates[coordinates.length-1].lng},${coordinates[coordinates.length-1].lat}`; // 终点
  
  const response = await fetch(url);
  return response.blob();
}

// 坐标压缩（简化存储）
function compressCoordinates(coords: Coordinate[]): string {
  // 使用Douglas-Peucker算法简化路线，保留关键形状点
  const simplified = simplify(coords, tolerance: 0.0001);
  return JSON.stringify(simplified);
}
```

### 2.3 徒步历史页面重构

**移除模拟数据，接入真实数据**：

```typescript
// API接口定义
interface HikingHistoryAPI {
  // 获取用户的徒步历史列表
  GET /api/hiking-records?userId={userId}&page={page}&limit={limit}
  
  // 获取单条详情
  GET /api/hiking-records/{recordId}
  
  // 删除记录
  DELETE /api/hiking-records/{recordId}
}

// React Query封装
function useHikingHistory(userId: string) {
  return useQuery({
    queryKey: ['hiking-records', userId],
    queryFn: async () => {
      const response = await api.get(`/hiking-records?userId=${userId}`);
      return response.data;
    },
    staleTime: 5 * 60 * 1000, // 5分钟缓存
  });
}

// 统计计算（前端聚合）
function useHistoryStats(records: HikingRecord[]) {
  return useMemo(() => {
    return records.reduce((stats, record) => ({
      totalCount: stats.totalCount + 1,
      totalDistance: stats.totalDistance + record.distance,
      totalElevationGain: stats.totalElevationGain + record.elevationGain
    }), {
      totalCount: 0,
      totalDistance: 0,
      totalElevationGain: 0
    });
  }, [records]);
}
```

**页面结构更新**：

```typescript
<HikingHistoryPage>
  {/* 统计栏 - 更新为累计数据 */}
  <StatsSummaryBar>
    <StatBox 
      icon="number"
      label="累计次数"
      value={stats.totalCount}
      unit="次"
    />
    <StatBox 
      icon="arrow.left.and.right"
      label="总距离"
      value={stats.totalDistance.toFixed(1)}
      unit="km"
    />
    <StatBox 
      icon="arrow.up.forward"
      label="累计海拔爬升"
      value={stats.totalElevationGain}
      unit="m"
    />
  </StatsSummaryBar>
  
  {/* 月份分组列表 */}
  <SectionList
    sections={groupRecordsByMonth(records)}
    renderSectionHeader={({section}) => (
      <MonthHeader>{section.title}</MonthHeader>
    )}
    renderItem={({item}) => (
      <HistoryCard 
        record={item}
        isHighlighted={item.id === route.params?.highlight}
      />
    )}
    keyExtractor={item => item.id}
    ListEmptyComponent={<EmptyState />}
  />
</HikingHistoryPage>
```

**历史卡片组件（真实数据）**：

```typescript
interface HistoryCardProps {
  record: HikingRecord;
  isHighlighted: boolean;
}

<HistoryCard 
  style={isHighlighted ? styles.highlightedCard : null}
  onPress={() => navigateToDetail(record.id)}
>
  <CardHeader>
    <DateLabel>{formatDate(record.startTime)}</DateLabel>
    <DurationTag>{formatDuration(record.duration)}</DurationTag>
  </CardHeader>
  
  {/* 地图缩略图 - 使用真实截图 */}
  <MapThumbnail 
    source={{uri: record.mapSnapshotUrl}}
    fallback={<MapPlaceholder />}
  />
  
  <CardBody>
    <LocationRow>
      <Icon name="mappin" size={14} color="#757575" />
      <Text numberOfLines={1}>
        {record.startLocationName} → {record.endLocationName}
      </Text>
    </LocationRow>
    
    <StatsRow>
      <MiniStat 
        icon="arrow.left.and.right"
        value={`${record.distance.toFixed(1)}km`}
      />
      <MiniStat 
        icon="flame"
        value={`${record.calories}千卡`}
      />
      <MiniStat 
        icon="arrow.up.forward"
        value={`${record.elevationGain}m`}
      />
    </StatsRow>
  </CardBody>
  
  {record.messageCount > 0 && (
    <CardFooter>
      <Badge icon="bubble.left" count={record.messageCount} />
      <Text>{record.messageCount} 条消息</Text>
    </CardFooter>
  )}
</HistoryCard>

// 高亮动画样式
const styles = StyleSheet.create({
  highlightedCard: {
    borderColor: '#2E7D32',
    borderWidth: 2,
    backgroundColor: '#E8F5E9',
  }
});
```

---

## 三、历史详情页与轨迹回放

### 3.1 徒步详情页数据展示

```typescript
interface HikingDetailData extends HikingRecord {
  // 扩展详情数据
  altitudeData: Array<{timestamp: number; altitude: number}>;
  speedData: Array<{timestamp: number; speed: number}>;
  participants: Array<Participant>;
}

<HikingDetailPage>
  <Header title="徒步详情" />
  
  <ScrollView>
    {/* 1. 轨迹地图回放区 */}
    <TrajectoryReplaySection record={record} />
    
    {/* 2. 核心数据卡片 */}
    <StatsGrid>
      <StatCard 
        icon="clock"
        label="运动时长"
        value={formatDuration(record.duration)}
        subValue={`暂停 ${formatDuration(record.totalPauseTime)}`}
      />
      <StatCard 
        icon="arrow.left.and.right"
        label="距离"
        value={`${record.distance.toFixed(2)}km`}
        subValue={`配速 ${calculatePace(record.duration, record.distance)}/km`}
      />
      <StatCard 
        icon="flame.fill"
        label="热量消耗"
        value={`${record.calories}千卡`}
      />
      <StatCard 
        icon="arrow.up.forward"
        label="海拔爬升"
        value={`${record.elevationGain}m`}
        subValue={`最高 ${record.maxAltitude}m`}
      />
    </StatsGrid>
    
    {/* 3. 海拔曲线图 */}
    <AltitudeChart data={record.altitudeData} />
    
    {/* 4. 速度曲线图 */}
    <SpeedChart data={record.speedData} />
    
    {/* 5. 路线信息 */}
    <RouteInfoSection>
      <InfoRow label="开始时间" value={formatFullTime(record.startTime)} />
      <InfoRow label="结束时间" value={formatFullTime(record.endTime)} />
      <InfoRow label="起点位置" value={record.startLocationName} />
      <InfoRow label="终点位置" value={record.endLocationName} />
      <InfoRow label="轨迹点数" value={`${record.coordinateCount} 个点`} />
    </RouteInfoSection>
    
    {/* 6. 消息回顾入口 */}
    {record.messageCount > 0 && (
      <MessageHistoryEntry hikeId={record.id} />
    )}
    
    {/* 7. 操作按钮 */}
    <ActionButtons>
      <Button 
        title="导出GPX"
        onPress={exportGPX}
        variant="outline"
      />
      <Button 
        title="分享轨迹"
        onPress={shareTrajectory}
        variant="outline"
      />
      <Button 
        title="删除记录"
        onPress={confirmDelete}
        variant="danger"
      />
    </ActionButtons>
  </ScrollView>
</HikingDetailPage>
```

### 3.2 轨迹地图回放组件

```typescript
interface TrajectoryReplayProps {
  record: HikingRecord;
}

<TrajectoryReplaySection>
  <SectionHeader>
    <Title>轨迹地图</Title>
    {record.mapSnapshotUrl && (
      <ToggleButton 
        options={['截图', '回放']}
        selected={viewMode}
        onChange={setViewMode}
      />
    )}
  </SectionHeader>
  
  <MapContainer height={300}>
    {viewMode === 'snapshot' ? (
      /* 模式1：静态截图（默认） */
      <MapSnapshot 
        source={{uri: record.mapSnapshotUrl}}
        resizeMode="cover"
        onPress={() => setViewMode('replay')} // 点击切换回放
      />
    ) : (
      /* 模式2：交互式回放 */
      <TrajectoryPlayer record={record} />
    )}
  </MapContainer>
  
  {viewMode === 'snapshot' && (
    <TapHint>点击查看交互式回放</TapHint>
  )}
</TrajectoryReplaySection>

// 轨迹回放播放器
function TrajectoryPlayer({ record }: { record: HikingRecord }) {
  const [progress, setProgress] = useState(0); // 0-100
  const [isPlaying, setIsPlaying] = useState(false);
  const mapRef = useRef<AMapView>(null);
  
  // 解析坐标
  const coordinates = useMemo(() => {
    return JSON.parse(record.coordinatesJson || '[]');
  }, [record]);
  
  // 回放动画
  useEffect(() => {
    if (!isPlaying) return;
    
    const duration = 5000; // 5秒回放完
    const startTime = Date.now();
    
    const animate = () => {
      const elapsed = Date.now() - startTime;
      const newProgress = Math.min((elapsed / duration) * 100, 100);
      setProgress(newProgress);
      
      // 更新地图显示的点数
      const visibleCount = Math.floor((newProgress / 100) * coordinates.length);
      const visibleCoords = coordinates.slice(0, visibleCount);
      
      mapRef.current?.updatePolyline(visibleCoords);
      mapRef.current?.setCenter(visibleCoords[visibleCoords.length - 1]);
      
      if (newProgress < 100) {
        requestAnimationFrame(animate);
      } else {
        setIsPlaying(false);
      }
    };
    
    animate();
  }, [isPlaying, coordinates]);
  
  return (
    <View style={{flex: 1}}>
      <AMapView
        ref={mapRef}
        initialRegion={{
          latitude: record.startLat,
          longitude: record.startLng,
          latitudeDelta: 0.01,
          longitudeDelta: 0.01,
        }}
        showsUserLocation={false}
      >
        {/* 完整路线（灰色背景） */}
        <Polyline 
          coordinates={coordinates}
          strokeColor="#E0E0E0"
          strokeWidth={4}
        />
        
        {/* 已播放路线（绿色） */}
        <Polyline 
          coordinates={coordinates.slice(0, Math.floor((progress/100)*coordinates.length))}
          strokeColor="#2E7D32"
          strokeWidth={4}
        />
        
        {/* 起点标记 */}
        <Marker coordinate={coordinates[0]}>
          <StartPointLabel>A</StartPointLabel>
        </Marker>
        
        {/* 终点标记 */}
        <Marker coordinate={coordinates[coordinates.length - 1]}>
          <EndPointLabel>B</EndPointLabel>
        </Marker>
        
        {/* 当前位置标记 */}
        {progress > 0 && progress < 100 && (
          <Marker 
            coordinate={getCurrentPosition(coordinates, progress)}
          >
            <CurrentPositionDot />
          </Marker>
        )}
      </AMapView>
      
      {/* 播放控制栏 */}
      <PlayerControls>
        <IconButton 
          icon={isPlaying ? 'pause.fill' : 'play.fill'}
          onPress={() => setIsPlaying(!isPlaying)}
        />
        <ProgressSlider 
          value={progress}
          onValueChange={setProgress}
        />
        <TimeLabel>
          {formatTime((progress/100) * record.duration)}
        </TimeLabel>
      </PlayerControls>
    </View>
  );
}
```

### 3.3 数据获取API

```typescript
// 获取徒步详情
GET /api/hiking-records/{recordId}

Response:
{
  "id": "uuid",
  "userId": "uuid",
  "startTime": 1704067200000,
  "endTime": 1704070800000,
  "duration": 3600000,
  "distance": 5.23,
  "calories": 330,
  "elevationGain": 150,
  "maxAltitude": 850,
  "minAltitude": 700,
  "coordinatesJson": "[{\"lat\":39.9,\"lng\":116.4,\"altitude\":720},...]", // 简化后坐标
  "mapSnapshotUrl": "https://cdn.example.com/snapshots/uuid.jpg",
  "startLocationName": "香山公园东门",
  "endLocationName": "香山山顶",
  "messageCount": 3,
  "participantCount": 2,
  "createdAt": "2024-01-01T00:00:00Z"
}

// 获取详细轨迹数据（用于回放）
GET /api/hiking-records/{recordId}/trajectory

Response:
{
  "coordinates": [
    {"timestamp": 1704067200000, "lat": 39.9, "lng": 116.4, "altitude": 720, "speed": 0},
    {"timestamp": 1704067210000, "lat": 39.9001, "lng": 116.4001, "altitude": 722, "speed": 1.2},
    // ... 每秒一个点
  ],
  "simplifiedPath": "39.9,116.4;39.901,116.401;..." // 用于静态图
}
```

---

## 四、接口对接清单

### 4.1 前端→后端接口

| 接口                                  | 方法   | 用途         | 请求体              |
| ------------------------------------- | ------ | ------------ | ------------------- |
| `/api/hiking-records`                 | POST   | 保存徒步记录 | HikingFinalData     |
| `/api/hiking-records`                 | GET    | 获取历史列表 | userId, page, limit |
| `/api/hiking-records/{id}`            | GET    | 获取详情     | -                   |
| `/api/hiking-records/{id}`            | DELETE | 删除记录     | -                   |
| `/api/hiking-records/{id}/trajectory` | GET    | 获取详细轨迹 | -                   |
| `/api/upload/snapshot`                | POST   | 上传地图截图 | multipart/form-data |

### 4.2 高德地图接口

| 接口                   | 用途             | 调用时机     |
| ---------------------- | ---------------- | ------------ |
| `v3/staticmap`         | 生成轨迹截图     | 结束徒步时   |
| `v3/elevation/point`   | 获取海拔         | 初始化时     |
| `v3/grasproad/driving` | 轨迹纠偏（可选） | 计算距离时   |
| `v3/geocode/regeo`     | 逆地理编码       | 获取地点名称 |

### 4.3 本地存储

```typescript
// 使用AsyncStorage/IndexedDB缓存
const StorageKeys = {
  CURRENT_HIKE: '@current_hike',           // 当前进行中的徒步（防丢失）
  HISTORY_CACHE: '@hiking_history',        // 历史列表缓存
  STATS_CACHE: '@hiking_stats',            // 统计数据缓存
  OFFLINE_QUEUE: '@offline_queue',         // 离线待同步队列
};
```

---

## 五、性能优化要点

1. **坐标采样**：每秒记录一次，但上传前使用Douglas-Peucker算法简化，保留形状同时减少90%数据量
2. **图片压缩**：地图截图使用WebP格式，质量80%，目标大小<200KB
3. **分页加载**：历史列表每页20条，下拉加载更多
4. **缓存策略**：详情页数据缓存5分钟，列表缓存2分钟
5. **后台同步**：弱网环境下先存本地，恢复网络后自动同步

---

此PRD完整覆盖了三个核心需求的技术实现方案，可直接用于开发排期。