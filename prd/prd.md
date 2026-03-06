

## solitary页面设计需求

| 页面名称       | 所属Tab  | 页面描述                                                     | 主要功能区域构建                                             |
| -------------- | -------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| **徒步地图**   | 开始徒步 | 核心地图页面，展示用户位置、周围徒步者、路线记录，支持一键求救和发送消息 | **顶部状态栏**：显示当前徒步状态（未开始/进行中）、GPS信号强度、已徒步时长<br>**中央地图区**：高德地图自定义图层，显示：①用户当前位置（蓝色箭头）②周围可见用户（绿色圆点，点击显示距离和基本信息）③已记录路线（蓝色实线）④区域聚合边界（半透明虚线）<br>**底部操作栏**：左侧「开始/结束徒步」大按钮（红色/绿色状态切换），右侧「求救」紧急按钮（红色SOS图标，需二次确认）<br>**悬浮按钮**：右下角「发消息」按钮（展开后显示：向周围人提问/发布路况反馈） |
| **求救详情**   | 开始徒步 | 一键求救后的补充信息填写页面，用于完善求救信息               | **顶部提示**：红色警示区域，显示"求救信号已发送给周围3位最近用户"<br>**表单区域**：①危险类型（单选：受伤/迷路/天气突变/野生动物/其他）②当前安全状态（切换：仍危险/已暂时安全/已完全脱险）③急需物品（多选：水/食物/药品/保暖装备/导航帮助/专业救援）④具体描述（文本输入，限制100字）⑤拍照上传（可选，最多3张）<br>**底部按钮**：「更新求救信息」（推送更新给接收者）和「取消求救」（仅当状态为"已完全脱险"时可点击） |
| **路线反馈**   | 开始徒步 | 发布实时路况信息的页面                                       | **快速标签区**：横向滚动标签（道路阻断/天气变化/危险动物/水源位置/推荐营地/其他）<br>**详情输入**：具体描述（文本）+ 拍照（可选）<br>**影响范围**：自动计算该反馈对哪些相似路线用户可见<br>**发布按钮**：确认后推送给相关用户 |
| **向他人提问** | 开始徒步 | 向周围相似路线用户发送问题的页面                             | **接收者范围**：显示"将发送给周围X位路线相似的用户"<br>**问题模板**：快捷选择（前方路况如何？/还有多久到山顶？/前方有水源吗？/推荐在哪里露营？）<br>**自定义输入**：支持自定义问题（限制50字）<br>**发送按钮**：发送后等待回复，显示在临时消息中 |
| **好友消息**   | 消息     | 永久好友的聊天列表和对话页面                                 | **列表页**：好友头像+昵称+最后消息预览+未读红点+时间，按最后消息时间倒序<br>**聊天页**：标准气泡对话界面，支持文字、图片、位置分享<br>**空状态**：无好友时显示"在徒步中点击'合拍'添加志同道合的朋友" |
| **临时消息**   | 消息     | 本次徒步活动的临时聊天，包括接收的求救、路况反馈、他人提问   | **顶部标签**：「求救求助」（红色标记优先级）/「路况反馈」（黄色）/「问答交流」（蓝色）<br>**消息列表**：显示发送者距离、发送时间、消息类型图标、内容预览<br>**聊天页**：显示"临时会话 - 距离您X米"，对话底部提示"本次徒步结束后将无法继续联系"<br>**快捷操作**：在聊天界面可直接点击对方头像旁的「合拍」按钮 |
| **历史徒步**   | 开始徒步 | 查看历史徒步记录列表                                         | **列表项**：每次徒步卡片包含：地图缩略图（静态截图）、日期、时长、距离、路线名称（可编辑）<br>**筛选标签**：可按月份/地点/距离筛选<br>**空状态**：首次使用引导"开始您的第一次徒步探索" |
| **历史详情**   | 开始徒步 | 单次历史徒步的详细查看                                       | **顶部地图**：静态展示该次路线轨迹和当时周围用户分布（历史快照）<br>**统计信息**：总距离、总时长、平均速度、最高海拔<br>**消息回顾**：折叠面板展示该次徒步的所有临时消息记录（只读，不可回复）<br>**合拍好友**：显示该次徒步中通过「合拍」添加的好友 |
| **隐私安全**   | 设置     | 核心隐私配置页面，控制可见性和接收权限                       | **可见性设置**：开关"在地图上显示我的位置"，开启后选择范围（1km/3km/5km/10km单选）<br>**接收设置**：①接收求救信息（开关，默认开）②接收周围提问（开关，默认开）③接收路况反馈（开关，默认开，可配置仅接收"道路阻断"类紧急反馈）<br>**危险词过滤**：是否开启敏感内容过滤 |
| **账号与安全** | 设置     | 登录方式管理和账号信息                                       | **登录状态**：当前登录方式（微信/手机）显示<br>**绑定管理**：微信绑定/解绑、手机号更换<br>**账号信息**：昵称、头像编辑<br>**注销账号**：底部红色文字按钮，需二次确认 |
| **语言设置**   | 设置     | 应用语言切换                                                 | **选项**：简体中文 / English<br>**预览**：切换时实时预览关键界面文案<br>**自动检测**：可选跟随系统语言 |
| **关于与帮助** | 设置     | 应用信息和使用指南                                           | **使用指南**：图文说明核心功能（如何求救、如何添加好友、隐私保护机制）<br>**安全提示**：户外徒步安全知识卡片<br>**关于我们**：版本号、用户协议、隐私政策<br>**联系反馈**：问题反馈入口 |

## 设计说明

**精简原则体现：**
1. **无个人主页**：本产品强调匿名互助，不需要展示个人资料页，减少社交压力
2. **无搜索功能**：用户通过地理位置和路线自动聚合，无需主动搜索添加
3. **无通知中心**：消息直接体现在"消息"Tab的Badge数字上，求救信息在App内强提醒+手机系统通知
4. **无好友推荐**：好友只能通过徒步中的实际互动（发消息+互点合拍）建立，保证关系真实

**关键交互流程：**
- 开始徒步 → 进入地图页 → 后台记录轨迹 → 遇到情况可求救/发反馈/提问 → 结束徒步 → 历史记录保存 → 临时消息归档 → 合拍好友转为永久联系

**安全设计：**
- 求救按钮需长按3秒或二次确认，防止误触
- 隐私设置默认保守（可见范围1km，接收全开但可细调）
- 临时消息机制保护用户，避免徒步结束后被骚扰



---

## 一、全局设计规范

### 1.1 设计系统
| 属性             | 规格                                                         |
| ---------------- | ------------------------------------------------------------ |
| **设计尺寸基准** | iPhone 14 Pro (393×852pt) 为主，适配 iPhone SE 375×667pt 到 iPhone 15 Pro Max 430×932pt |
| **色彩系统**     | 主色：#2E7D32 (徒步绿) / 警示色：#D32F2F (求救红) / 背景：#F5F5F5 / 卡片：#FFFFFF / 文字主色：#212121 / 次要文字：#757575 |
| **字体**         | 中文：PingFang SC / 英文：SF Pro，层级：标题 18pt Bold / 正文 16pt Regular / 辅助 14pt Regular / 标签 12pt Medium |
| **圆角规范**     | 卡片 12px / 按钮 8px / 头像 50% / 输入框 6px                 |
| **间距系统**     | 基础单位 8px，常用：8/16/24/32px                             |
| **图标库**       | 使用 SF Symbols 或自定义 SVG，尺寸：24×24pt (标准) / 48×48pt (底部Tab) |

### 1.2 全局状态管理
```typescript
// 核心全局状态 (Redux/Zustand)
interface GlobalState {
  user: {
    id: string;
    nickname: string;
    avatar: string;
    phone?: string;
    wechatBound: boolean;
    language: 'zh-CN' | 'en';
  };
  currentHike: {
    isActive: boolean;
    hikeId: string | null;
    startTime: number | null;
    currentLocation: { lat: number; lng: number } | null;
    routeCoordinates: Array<{lat: number; lng: number; timestamp: number}>;
    nearbyUsers: Array<NearbyUser>;
    regionId: string | null; // 当前所在聚合区域ID
  };
  privacySettings: {
    visibleOnMap: boolean;
    visibleRange: 1 | 3 | 5 | 10; // 公里
    receiveSOS: boolean;
    receiveQuestions: boolean;
    receiveFeedback: boolean;
    feedbackFilter: 'all' | 'danger-only'; // 路况反馈过滤
  };
  sosStatus: {
    isActive: boolean;
    sosId: string | null;
    recipients: Array<{userId: string; distance: number}>;
    lastUpdateTime: number;
  };
}
```

### 1.3 底部TabBar结构
```
┌─────────────────────────────────────────────────────────┐
│  [Tab: 开始徒步]        [Tab: 消息]        [Tab: 设置]   │
│  图标: 地图.fill        图标: 气泡.fill     图标: 齿轮    │
│  选中态: 绿色#2E7D32    有未读时显示红点               │
└─────────────────────────────────────────────────────────┘
特殊逻辑：
- "开始徒步"Tab：未开始徒步时显示地图预览态，开始后显示记录态
- "消息"Tab：Badge数字 = 永久好友未读 + 当前徒步临时消息未读
- 徒步进行中时，TabBar上方悬浮显示"记录中"绿色指示条
```

---

## 二、Tab: 开始徒步

### 2.1 页面：徒步地图 (HikingMap)

**页面路由**: `/hiking/map`  
**页面状态**: 未开始徒步 / 徒步进行中 / 求救中

#### 2.1.1 页面布局结构
```
┌─────────────────────────────────────────┐
│  状态栏 (StatusBar) - 系统级            │
├─────────────────────────────────────────┤
│  顶部信息栏 (TopInfoBar) - 高度 60pt    │
├─────────────────────────────────────────┤
│                                         │
│                                         │
│     地图区域 (MapContainer)             │
│     占满剩余空间                        │
│                                         │
│                                         │
├─────────────────────────────────────────┤
│  底部操作栏 (BottomActionBar) - 高度    │
│  未开始: 100pt / 进行中: 140pt          │
└─────────────────────────────────────────┘
悬浮元素：
- 右侧工具栏 (RightToolbar) - 地图右上角
- 求救详情入口 (SOSDetailEntry) - 求救时出现，地图左上角
- 消息快捷入口 (QuickMessageEntry) - 地图左下角
```

#### 2.1.2 顶部信息栏 (TopInfoBar)
```typescript
interface TopInfoBarProps {
  hikeStatus: 'idle' | 'recording' | 'paused' | 'sos';
  gpsSignal: 'strong' | 'weak' | 'none'; // 根据精度判断
  duration: number; // 已徒步秒数，格式化 00:00:00
  currentRegion?: string; // 当前聚合区域名称，如"香山区域-3号分组"
}

// UI结构
<TopInfoBar>
  <LeftSection>
    <GPSIndicator>
      <Icon name="location.fill" color={gpsSignal === 'strong' ? '#2E7D32' : '#FF9800'} />
      <Text>{gpsSignal === 'strong' ? 'GPS信号良好' : 'GPS信号弱'}</Text>
    </GPSIndicator>
    {hikeStatus !== 'idle' && (
      <RegionTag>
        <Icon name="person.2.fill" size={12} />
        <Text>{currentRegion || '未分组'}</Text>
      </RegionTag>
    )}
  </LeftSection>
  
  <CenterSection>
    {hikeStatus !== 'idle' && (
      <DurationDisplay>
        <Text style={{fontSize: 24, fontWeight: 'bold', fontVariant: ['tabular-nums']}}>
          {formatDuration(duration)}
        </Text>
        <Text style={{fontSize: 12, color: '#757575'}}>徒步时长</Text>
      </DurationDisplay>
    )}
  </CenterSection>
  
  <RightSection>
    {hikeStatus === 'sos' && (
      <SOSBadge>
        <PulsingDot color="#D32F2F" />
        <Text style={{color: '#D32F2F', fontWeight: 'bold'}}>求救中</Text>
      </SOSBadge>
    )}
  </RightSection>
</TopInfoBar>
```

#### 2.1.3 地图区域 (MapContainer) - 核心组件
```typescript
interface MapContainerProps {
  mapType: 'standard' | 'satellite' | 'terrain';
  userLocation: {lat: number; lng: number; heading: number}; // heading为方向角度
  routeCoordinates: Array<{lat: number; lng: number}>;
  nearbyUsers: Array<NearbyUser>;
  visibleRange: number; // 当前设置的可见范围（公里）
  clusters: Array<Cluster>; // 聚合区域数据
  selectedUserId?: string; // 当前选中的用户（点击地图上的点）
  sosRecipients?: Array<{userId: string; location: {lat: number; lng: number}}>; // 求救接收者位置
}

interface NearbyUser {
  id: string;
  location: {lat: number; lng: number};
  distance: number; // 米
  isVisible: boolean; // 该用户是否开启可见
  routeSimilarity: number; // 路线相似度 0-100，用于分组
  lastUpdate: number; // 最后位置更新时间
  isFriend: boolean; // 是否为永久好友（显示不同颜色）
}

// 地图图层层级（从底到顶）
const MapLayers = {
  baseMap: '高德地图底图',
  heatmap: '徒步热度图层（可选）',
  clusterOverlay: '聚合区域半透明边界（多边形，stroke: #2E7D32, fill: rgba(46,125,50,0.1)）',
  routeLines: '所有可见用户的路线（细线，灰色#9E9E9E，透明度0.5）',
  myRoute: '我的路线（粗线3pt，主色#2E7D32，实线）',
  otherUsers: '其他用户位置（圆点，颜色根据关系：陌生人#4CAF50，好友#2196F3，求救接收者#D32F2F）',
  myLocation: '我的位置（蓝色箭头，带方向指示，外圈脉冲动画表示精度范围）',
  sosRadius: '求救影响范围（虚线圆，半径根据最近接收者距离动态计算）',
};

// 地图交互
-  pinch/spread: 缩放地图，范围 50m - 50km
-  pan: 拖动地图，拖动后显示"回到我的位置"按钮
-  tap on user marker: 选中用户，底部弹出用户操作卡片
-  long press on map: 快速标记兴趣点（仅自己可见）
-  rotate: 双指旋转地图（可选，默认锁定为正北朝上）
```

#### 2.1.4 用户标记点 (UserMarker) 详细设计
```typescript
// 用户标记点组件
<UserMarker>
  {/* 外圈：精度范围，透明度0.2 */}
  <AccuracyCircle radius={location.accuracy} color={getUserColor(user)} />
  
  {/* 内圈：用户位置 */}
  <LocationDot 
    size={user.id === currentUserId ? 24 : 16}
    color={getUserColor(user)}
    pulse={user.id === currentUserId} // 自己位置有脉冲动画
  >
    {/* 如果是好友，显示小图标 */}
    {user.isFriend && <Icon name="star.fill" size={8} color="#FFF" />}
  </LocationDot>
  
  {/* 信息标签（选中时显示） */}
  {isSelected && (
    <InfoBubble onPress={handleUserPress}>
      <Text>距离 {formatDistance(user.distance)}</Text>
      <Text>路线相似度 {user.routeSimilarity}%</Text>
      {user.isFriend ? (
        <ActionButton>发消息</ActionButton>
      ) : (
        <ActionButton>提问 / 求救</ActionButton>
      )}
    </InfoBubble>
  )}
</UserMarker>

// 颜色规则
function getUserColor(user: NearbyUser): string {
  if (user.id === currentUserId) return '#2196F3'; // 自己：蓝色
  if (sosRecipients?.includes(user.id)) return '#D32F2F'; // 求救接收者：红色
  if (user.isFriend) return '#FF9800'; // 好友：橙色
  return '#4CAF50'; // 陌生人：绿色
}
```

#### 2.1.5 右侧工具栏 (RightToolbar)
```typescript
// 垂直排列，位于地图右上角，距边缘16px
<RightToolbar>
  <ToolButton 
    icon="layers.fill" 
    onPress={() => setMapType(nextType)} // 切换地图类型
    label={mapType === 'standard' ? '标准' : '卫星'}
  />
  <ToolButton 
    icon="location.fill" 
    onPress={centerToMyLocation} // 回到当前位置
    active={isCentered}
  />
  <ToolButton 
    icon="person.2.fill" 
    onPress={toggleNearbyList} // 显示周围用户列表（侧滑面板）
    badge={nearbyUsers.length}
  />
  <ToolButton 
    icon="eye.fill" 
    onPress={toggleVisibleRange} // 快速切换可见范围
    label={`${visibleRange}km`}
  />
</RightToolbar>
```

#### 2.1.6 底部操作栏 (BottomActionBar) - 状态区分

**状态A：未开始徒步**
```typescript
<BottomActionBar height={100}>
  <SafetyTipsCarousel 
    // 横向滚动安全提示卡片
    tips={[
      '开启GPS定位以记录路线',
      '建议提前下载离线地图',
      '单人徒步请开启位置共享',
      '遇到危险可使用一键求救'
    ]}
    autoPlay={true}
    interval={5000}
  />
  <StartButton 
    onPress={startHiking}
    disabled={gpsSignal === 'none'}
  >
    <Icon name="play.fill" size={24} color="#FFF" />
    <Text style={{color: '#FFF', fontSize: 18, fontWeight: 'bold', marginLeft: 8}}>
      开始徒步
    </Text>
  </StartButton>
</BottomActionBar>

// StartButton样式
const StartButton = styled.TouchableOpacity`
  background: ${props => props.disabled ? '#BDBDBD' : '#2E7D32'};
  height: 56px;
  border-radius: 28px;
  flex-direction: row;
  align-items: center;
  justify-content: center;
  margin: 16px 24px;
  shadow-color: #000;
  shadow-offset: 0px 4px;
  shadow-opacity: 0.2;
  shadow-radius: 8px;
  elevation: 5;
`;
```

**状态B：徒步进行中**
```typescript
<BottomActionBar height={140}>
  <StatsRow>
    <StatItem label="距离" value={`${(distance/1000).toFixed(2)} km`} />
    <StatItem label="海拔" value={`${altitude} m`} />
    <StatItem label="速度" value={`${currentSpeed} km/h`} />
  </StatsRow>
  
  <ActionRow>
    <SecondaryButton onPress={pauseHiking}>
      <Icon name="pause.fill" />
      <Text>休息</Text>
    </SecondaryButton>
    
    <SOSButton 
      onPress={triggerSOS}
      // 需要长按3秒或二次确认
      onLongPress={confirmSOS}
      progress={sosPressProgress} // 长按进度环
    >
      <Icon name="exclamationmark.triangle.fill" size={32} color="#FFF" />
      <Text style={{color: '#FFF', fontWeight: 'bold'}}>求救</Text>
    </SOSButton>
    
    <SecondaryButton onPress={endHiking}>
      <Icon name="stop.fill" />
      <Text>结束</Text>
    </SecondaryButton>
  </ActionRow>
  
  <QuickActions>
    <QuickActionButton onPress={openQuestionModal}>
      <Icon name="questionmark.bubble.fill" />
      <Text>提问</Text>
    </QuickActionButton>
    <QuickActionButton onPress={openFeedbackModal}>
      <Icon name="exclamationmark.bubble.fill" />
      <Text>报路况</Text>
    </QuickActionButton>
    <QuickActionButton onPress={openCamera}>
      <Icon name="camera.fill" />
      <Text>拍照</Text>
    </QuickActionButton>
  </QuickActions>
</BottomActionBar>

// SOSButton特殊交互
const SOSButton = styled.TouchableOpacity`
  width: 80px;
  height: 80px;
  border-radius: 40px;
  background: #D32F2F;
  align-items: center;
  justify-content: center;
  border: 4px solid #FFCDD2; // 外圈警示色
  // 脉冲动画
  animation: pulse 2s infinite;
`;
```

#### 2.1.7 求救状态覆盖层 (SOSOverlay)
当 `sosStatus.isActive === true` 时，地图上方显示：
```typescript
<SOSOverlay>
  <TopBanner>
    <PulsingRedBackground />
    <Icon name="sos" size={32} color="#FFF" />
    <Text style={{color: '#FFF', fontSize: 16, fontWeight: 'bold'}}>
      求救信号已发送给周围 {sosStatus.recipients.length} 人
    </Text>
    <TouchableOpacity onPress={navigateToSOSDetail}>
      <Text style={{color: '#FFF', textDecorationLine: 'underline'}}>
        补充详情
      </Text>
    </TouchableOpacity>
  </TopBanner>
  
  {/* 地图上高亮显示接收者位置 */}
  {sosStatus.recipients.map(recipient => (
    <RecipientMarker 
      key={recipient.userId}
      coordinate={recipient.location}
      distance={recipient.distance}
    />
  ))}
  
  {/* 底部常驻提示 */}
  <BottomReminder>
    <Text>保持冷静，等待救援。如情况变化请及时更新信息。</Text>
    <Button onPress={cancelSOS} disabled={!canCancel}>
      取消求救（仅安全后可用）
    </Button>
  </BottomReminder>
</SOSOverlay>
```

---

### 2.2 页面：求救详情 (SOSDetail)

**页面路由**: `/hiking/sos-detail`  
**进入方式**: 点击地图页"补充详情"或求救后自动跳转

#### 2.2.1 页面结构
```
┌─────────────────────────────────────────┐
│  导航栏：返回 + 标题"求救信息" + 提交    │
├─────────────────────────────────────────┤
│  顶部状态卡片 (SOSStatusCard)           │
├─────────────────────────────────────────┤
│  滚动表单区域 (ScrollView)              │
│  ├─ 危险类型选择                        │
│  ├─ 当前安全状态切换                    │
│  ├─ 急需物品多选                        │
│  ├─ 具体描述输入                        │
│  └─ 照片上传区域                        │
├─────────────────────────────────────────┤
│  底部操作区 (更新/取消)                 │
└─────────────────────────────────────────┘
```

#### 2.2.2 详细表单组件

**危险类型选择 (DangerTypeSelector)**
```typescript
interface DangerType {
  id: string;
  icon: string;
  label: string;
  labelEn: string;
  severity: 'high' | 'medium' | 'low';
}

const dangerTypes: DangerType[] = [
  {id: 'injury', icon: 'bandage.fill', label: '人员受伤', labelEn: 'Injury', severity: 'high'},
  {id: 'lost', icon: 'map.fill', label: '迷路失联', labelEn: 'Lost', severity: 'high'},
  {id: 'weather', icon: 'cloud.bolt.fill', label: '天气突变', labelEn: 'Weather', severity: 'high'},
  {id: 'animal', icon: 'pawprint.fill', label: '野生动物', labelEn: 'Wildlife', severity: 'medium'},
  {id: 'equipment', icon: 'backpack.fill', label: '装备故障', labelEn: 'Equipment', severity: 'medium'},
  {id: 'other', icon: 'exclamationmark.triangle.fill', label: '其他危险', labelEn: 'Other', severity: 'medium'},
];

<DangerTypeSelector>
  <SectionTitle>危险类型（必选）</SectionTitle>
  <Grid columns={3} spacing={12}>
    {dangerTypes.map(type => (
      <TypeCard 
        key={type.id}
        selected={selectedType === type.id}
        severity={type.severity}
        onPress={() => setSelectedType(type.id)}
      >
        <Icon name={type.icon} size={32} color={getSeverityColor(type.severity)} />
        <Text>{language === 'zh-CN' ? type.label : type.labelEn}</Text>
        {selectedType === type.id && <SelectedIndicator />}
      </TypeCard>
    ))}
  </Grid>
</DangerTypeSelector>

// 视觉反馈：高风险红色边框，选中后填充红色背景
```

**当前安全状态 (SafetyStatusToggle)**
```typescript
<SafetyStatusToggle>
  <SectionTitle>当前安全状态</SectionTitle>
  <SegmentedControl 
    values={['仍危险', '暂时安全', '已脱险']}
    selectedIndex={safetyStatus}
    onChange={setSafetyStatus}
    // 颜色区分：红色 / 黄色 / 绿色
    tintColor={['#D32F2F', '#FF9800', '#4CAF50'][safetyStatus]}
  />
  <StatusDescription>
    {safetyStatus === 0 && '请保持冷静，等待救援到达'}
    {safetyStatus === 1 && '危险暂时解除，但仍需协助'}
    {safetyStatus === 2 && '危险已完全解除，可取消求救'}
  </StatusDescription>
</SafetyStatusToggle>
```

**急需物品多选 (UrgentItemsSelector)**
```typescript
const urgentItems = [
  {id: 'water', icon: 'drop.fill', label: '饮用水', labelEn: 'Water'},
  {id: 'food', icon: 'fork.knife', label: '食物', labelEn: 'Food'},
  {id: 'medicine', icon: 'cross.case.fill', label: '药品', labelEn: 'Medicine'},
  {id: 'warmth', icon: 'flame.fill', label: '保暖装备', labelEn: 'Warmth'},
  {id: 'shelter', icon: 'tent.fill', label: '庇护所', labelEn: 'Shelter'},
  {id: 'navigation', icon: 'compass.fill', label: '导航帮助', labelEn: 'Navigation'},
  {id: 'rescue', icon: 'phone.fill.arrow.up.right', label: '专业救援', labelEn: 'Rescue'},
];

<UrgentItemsSelector>
  <SectionTitle>急需物品/帮助（多选）</SectionTitle>
  <FlowLayout spacing={8}>
    {urgentItems.map(item => (
      <Chip 
        key={item.id}
        selected={selectedItems.includes(item.id)}
        onPress={() => toggleItem(item.id)}
        icon={item.icon}
      >
        {language === 'zh-CN' ? item.label : item.labelEn}
      </Chip>
    ))}
  </FlowLayout>
</UrgentItemsSelector>
```

**照片上传 (PhotoUploader)**
```typescript
<PhotoUploader>
  <SectionTitle>现场照片（可选，最多3张）</SectionTitle>
  <HorizontalScroll>
    {photos.map((photo, index) => (
      <PhotoThumbnail 
        key={index}
        source={photo.uri}
        onDelete={() => removePhoto(index)}
      />
    ))}
    {photos.length < 3 && (
      <AddPhotoButton onPress={takePhotoOrSelect}>
        <Icon name="camera.fill" size={32} color="#757575" />
        <Text>添加照片</Text>
      </AddPhotoButton>
    )}
  </HorizontalScroll>
  <Text style={{fontSize: 12, color: '#757575', marginTop: 8}}>
    照片将发送给救援者，帮助判断情况
  </Text>
</PhotoUploader>
```

#### 2.2.3 提交与更新逻辑
```typescript
// 首次提交
const handleSubmit = async () => {
  const sosData = {
    type: selectedType,
    safetyStatus,
    urgentItems: selectedItems,
    description,
    photos,
    location: currentLocation,
    timestamp: Date.now(),
  };
  await api.post('/sos/create', sosData);
  // 推送给周围3个最近用户
  await notifyNearbyUsers(sosData, limit: 3);
};

// 更新信息（已求救状态下）
const handleUpdate = async () => {
  await api.post('/sos/update', {sosId, updates: formData});
  // 推送给同样的接收者
  await notifyRecipients(sosId, formData);
};
```

---

### 2.3 页面：路线反馈 (RouteFeedback)

**页面路由**: `/hiking/feedback`  
**进入方式**: 地图页点击"报路况"

#### 2.3.1 页面结构
```typescript
<RouteFeedbackPage>
  <Header title="发布路况信息" onClose={closeModal} />
  
  <ScrollView>
    {/* 影响范围预览 */}
    <ImpactPreviewCard>
      <MapThumbnail 
        region={currentRegion}
        highlightRadius={affectedRadius} // 根据路线相似度计算
      />
      <Text>该信息将影响周围 {affectedUsersCount} 位相似路线用户</Text>
    </ImpactPreviewCard>
    
    {/* 快速标签 */}
    <QuickTagsSection>
      <SectionTitle>路况类型</SectionTitle>
      <TagGrid>
        {feedbackTypes.map(type => (
          <FeedbackTag 
            key={type.id}
            selected={selectedType === type.id}
            color={type.color}
            onPress={() => selectType(type.id)}
          >
            <Icon name={type.icon} />
            <Text>{type.label}</Text>
          </FeedbackTag>
        ))}
      </TagGrid>
    </QuickTagsSection>
    
    {/* 详细描述 */}
    <DescriptionInput
      placeholder="描述具体情况，如：前方200米处有塌方，建议绕行左侧小路..."
      maxLength={200}
      value={description}
      onChangeText={setDescription}
    />
    
    {/* 位置微调 */}
    <LocationFineTune
      initialLocation={currentLocation}
      onLocationChange={setPreciseLocation}
      // 允许在地图上微调标记点
    />
    
    {/* 照片证据 */}
    <EvidencePhotos maxCount={2} onChange={setPhotos} />
    
    {/* 有效期设置 */}
    <ValiditySelector
      options={[
        {label: '1小时', value: 3600},
        {label: '3小时', value: 10800},
        {label: '今天', value: 'endOfDay'},
        {label: '永久', value: 'permanent'}, // 如道路损毁
      ]}
      selected={validity}
      onSelect={setValidity}
    />
  </ScrollView>
  
  <Footer>
    <Button 
      title="发布" 
      onPress={submitFeedback}
      disabled={!selectedType || !description}
    />
  </Footer>
</RouteFeedbackPage>
```

#### 2.3.2 反馈类型定义
```typescript
const feedbackTypes = [
  {id: 'blocked', icon: 'xmark.octagon.fill', label: '道路阻断', color: '#D32F2F', priority: 1},
  {id: 'detour', icon: 'arrow.triangle.turn.up.right.diamond.fill', label: '建议绕行', color: '#FF9800', priority: 2},
  {id: 'weather', icon: 'cloud.rain.fill', label: '天气变化', color: '#2196F3', priority: 2},
  {id: 'water', icon: 'drop.fill', label: '水源位置', color: '#03A9F4', priority: 3},
  {id: 'campsite', icon: 'tent.fill', label: '推荐营地', color: '#4CAF50', priority: 3},
  {id: 'viewpoint', icon: 'mountain.2.fill', label: '观景点', color: '#9C27B0', priority: 4},
  {id: 'danger', icon: 'exclamationmark.triangle.fill', label: '危险区域', color: '#D32F2F', priority: 1},
  {id: 'other', icon: 'ellipsis.bubble.fill', label: '其他信息', color: '#757575', priority: 5},
];
```

---

### 2.4 页面：向他人提问 (AskQuestion)

**页面路由**: `/hiking/ask`  
**进入方式**: 地图页点击"提问"或点击用户标记选择"提问"

#### 2.4.1 页面结构
```typescript
<AskQuestionPage>
  <Header title="向周围人提问" />
  
  {/* 接收者范围显示 */}
  <RecipientsCard>
    <Icon name="person.2.fill" />
    <Text>将发送给周围 {eligibleUsers.length} 位开启接收问题的用户</Text>
    <Text style={{fontSize: 12, color: '#757575'}}>
      仅路线相似度大于60%的用户可见
    </Text>
  </RecipientsCard>
  
  {/* 快捷问题模板 */}
  <QuickQuestions>
    <SectionTitle>快捷问题</SectionTitle>
    <List>
      {quickQuestions.map((q, index) => (
        <ListItem 
          key={index}
          title={q}
          onPress={() => setQuestion(q)}
          accessory="disclosure"
        />
      ))}
    </List>
  </QuickQuestions>
  
  {/* 自定义输入 */}
  <CustomInputSection>
    <SectionTitle>自定义问题</SectionTitle>
    <TextInput
      placeholder="输入您的问题，如：前方还有多久到山顶？"
      value={question}
      onChangeText={setQuestion}
      maxLength={50}
      showCharacterCount={true}
    />
  </CustomInputSection>
  
  {/* 悬赏机制（可选） */}
  <RewardSection>
    <Switch 
      value={hasReward}
      onValueChange={setHasReward}
    />
    <Text>添加感谢标记（对方回复后可发送感谢）</Text>
  </RewardSection>
  
  <Footer>
    <Button 
      title="发送" 
      onPress={sendQuestion}
      disabled={!question.trim() || eligibleUsers.length === 0}
    />
    {eligibleUsers.length === 0 && (
      <Text style={{color: '#D32F2F', fontSize: 12}}>
        周围暂无开启接收问题的用户
      </Text>
    )}
  </Footer>
</AskQuestionPage>
```

---

### 2.5 页面：历史徒步 (HikingHistory)

**页面路由**: `/hiking/history`  
**进入方式**: 地图页"历史记录"入口或设置中进入

#### 2.5.1 列表页结构
```typescript
<HikingHistoryList>
  <Header title="历史徒步" />
  
  {/* 统计概览 */}
  <StatsOverview>
    <StatBox label="总次数" value={totalCount} />
    <StatBox label="总距离" value={`${totalDistance}km`} />
    <StatBox label="总时长" value={formatDuration(totalDuration)} />
  </StatsOverview>
  
  {/* 筛选器 */}
  <FilterBar>
    <FilterChip 
      options={['全部', '本月', '今年', '更早']}
      selected={timeFilter}
      onSelect={setTimeFilter}
    />
    <SortButton 
      options={[
        {label: '最近优先', value: 'date-desc'},
        {label: '距离最长', value: 'distance-desc'},
        {label: '时长最长', value: 'duration-desc'},
      ]}
      selected={sortBy}
      onSelect={setSortBy}
    />
  </FilterBar>
  
  {/* 列表 */}
  <FlatList
    data={historyItems}
    renderItem={({item}) => <HistoryCard hike={item} />}
    keyExtractor={item => item.id}
    emptyComponent={
      <EmptyState 
        icon="map.fill"
        title="还没有徒步记录"
        description="开始您的第一次徒步探索吧"
        action={{title: '去徒步', onPress: () => navigate('/hiking/map')}}
      />
    }
  />
</HikingHistoryList>
```

#### 2.5.2 历史记录卡片 (HistoryCard)
```typescript
interface HistoryCardProps {
  hike: {
    id: string;
    date: string;
    duration: number;
    distance: number;
    routeName: string; // 可编辑，默认"徒步+日期"
    thumbnail: string; // 地图截图URL
    coordinateCount: number; // 轨迹点数量
    messageCount: number; // 该次临时消息数量
    newFriendsCount: number; // 该次新增好友数量
    startLocation: string; // 起点地名
    endLocation: string; // 终点地名
  };
}

<HistoryCard onPress={() => navigate(`/hiking/history/${hike.id}`)}>
  <CardHeader>
    <RouteNameEditable 
      value={hike.routeName}
      onChange={(name) => updateRouteName(hike.id, name)}
    />
    <DateLabel>{formatDate(hike.date)}</DateLabel>
  </CardHeader>
  
  <MapThumbnail source={hike.thumbnail} aspectRatio={16/9} />
  
  <CardFooter>
    <StatGroup>
      <Stat icon="clock" value={formatDuration(hike.duration)} />
      <Stat icon="arrow.left.and.right" value={`${hike.distance}km`} />
    </StatGroup>
    
    <BadgeGroup>
      {hike.messageCount > 0 && (
        <Badge icon="bubble.left" count={hike.messageCount} color="#2196F3" />
      )}
      {hike.newFriendsCount > 0 && (
        <Badge icon="person.badge.plus" count={hike.newFriendsCount} color="#4CAF50" />
      )}
    </BadgeGroup>
  </CardFooter>
</HistoryCard>
```

---

### 2.6 页面：历史详情 (HistoryDetail)

**页面路由**: `/hiking/history/:hikeId`

#### 2.6.1 页面结构
```typescript
<HistoryDetailPage>
  <Header 
    title={hike.routeName} 
    rightButton={{icon: 'square.and.arrow.up', onPress: shareRoute}}
  />
  
  <ScrollView>
    {/* 静态地图展示 */}
    <StaticMap 
      route={hike.coordinates}
      markers={hike.keyPoints} // 起点、终点、中途标记
      snapshot={true} // 禁止交互，仅展示
    />
    
    {/* 数据统计 */}
    <StatsGrid>
      <StatItem icon="clock" label="总时长" value={formatDuration(hike.duration)} />
      <StatItem icon="arrow.left.and.right" label="总距离" value={`${hike.distance}km`} />
      <StatItem icon="speedometer" label="平均速度" value={`${hike.avgSpeed}km/h`} />
      <StatItem icon="arrow.up.forward" label="最高海拔" value={`${hike.maxAltitude}m`} />
      <StatItem icon="arrow.down.forward" label="最低海拔" value={`${hike.minAltitude}m`} />
      <StatItem icon="calendar" label="徒步日期" value={formatDate(hike.date)} />
    </StatsGrid>
    
    {/* 海拔曲线图 */}
    <AltitudeChart data={hike.altitudeData} />
    
    {/* 消息回顾 - 只读 */}
    <Section title="本次徒步消息">
      {hike.messages.length > 0 ? (
        <MessageHistoryList>
          {hike.messages.map(msg => (
            <MessageItem 
              key={msg.id}
              type={msg.type} // sos/feedback/question
              sender={msg.senderName}
              content={msg.content}
              time={msg.timestamp}
              readonly={true}
              // 点击可查看详情，但不可回复
            />
          ))}
        </MessageHistoryList>
      ) : (
        <EmptyState description="本次徒步没有消息记录" />
      )}
    </Section>
    
    {/* 合拍好友 */}
    <Section title="本次新增好友">
      {hike.newFriends.map(friend => (
        <FriendItem 
          key={friend.id}
          user={friend}
          addedAt={friend.addedAt}
          context="本次徒步中通过'合拍'添加"
        />
      ))}
    </Section>
    
    {/* 操作按钮 */}
    <ActionButtons>
      <Button 
        title="再次徒步此路线" 
        onPress={restartHike}
        variant="secondary"
      />
      <Button 
        title="导出轨迹(GPX)" 
        onPress={exportGPX}
        variant="outline"
      />
      <Button 
        title="删除记录" 
        onPress={deleteHike}
        variant="danger"
      />
    </ActionButtons>
  </ScrollView>
</HistoryDetailPage>
```

---

## 三、Tab: 消息

### 3.1 页面：消息中心 (MessageCenter) - 主入口

**页面路由**: `/messages`  
**结构**: 顶部Tab切换器 + 列表内容

```typescript
<MessageCenterPage>
  <Header title="消息" />
  
  {/* 分段控制器 */}
  <SegmentedControl
    segments={[
      {id: 'friends', label: '好友', badge: friendsUnread},
      {id: 'temporary', label: '本次徒步', badge: tempUnread, hidden: !currentHike.isActive},
    ]}
    selected={activeTab}
    onSelect={setActiveTab}
  />
  
  {/* 内容区域 */}
  {activeTab === 'friends' ? <FriendsList /> : <TemporaryMessages />}
</MessageCenterPage>
```

### 3.2 页面：好友消息列表 (FriendsList)

```typescript
<FriendsList>
  <SearchBar 
    placeholder="搜索好友"
    value={searchQuery}
    onChangeText={setSearchQuery}
  />
  
  <FlatList
    data={filteredFriends}
    renderItem={({item}) => <FriendListItem friend={item} />}
    keyExtractor={item => item.id}
    emptyComponent={
      <EmptyState 
        icon="person.2.slash"
        title="还没有好友"
        description="在徒步中与他人交流后，点击'合拍'添加好友"
      />
    }
  />
</FriendsList>

// 好友列表项
<FriendListItem onPress={() => navigate(`/messages/friend/${friend.id}`)}>
  <Avatar source={friend.avatar} size={48} />
  <Content>
    <NameRow>
      <Name>{friend.nickname}</Name>
      <Time>{formatTime(friend.lastMessageTime)}</Time>
    </NameRow>
    <PreviewRow>
      <MessagePreview numberOfLines={1}>
        {friend.lastMessageContent}
      </MessagePreview>
      {friend.unreadCount > 0 && (
        <Badge count={friend.unreadCount} />
      )}
    </PreviewRow>
  </Content>
</FriendListItem>
```

### 3.3 页面：好友聊天页 (FriendChat)

**页面路由**: `/messages/friend/:friendId`

```typescript
<FriendChatPage>
  <Header 
    title={friend.nickname}
    rightButton={{icon: 'info.circle', onPress: showFriendInfo}}
  />
  
  <GiftedChat // 或自定义实现
    messages={messages}
    onSend={handleSend}
    user={{_id: currentUserId}}
    renderBubble={renderBubble}
    renderInputToolbar={renderInputToolbar}
    showUserAvatar={true}
    renderAvatarOnTop={true}
  />
  
  {/* 快捷操作面板（输入框上方） */}
  <InputAccessory>
    <QuickAction icon="location" onPress={sendLocation} />
    <QuickAction icon="photo" onPress={sendPhoto} />
    <QuickAction icon="mountain.2" onPress={shareRoute} />
  </InputAccessory>
</FriendChatPage>
```

### 3.4 页面：临时消息列表 (TemporaryMessages)

**仅在当前有进行中的徒步时显示**

```typescript
<TemporaryMessages>
  {/* 分类标签 */}
  <CategoryTabs>
    <Tab 
      label="全部" 
      active={category === 'all'} 
      onPress={() => setCategory('all')}
    />
    <Tab 
      label="求救" 
      active={category === 'sos'} 
      badge={sosCount}
      color="#D32F2F"
      hidden={sosCount === 0}
    />
    <Tab 
      label="路况" 
      active={category === 'feedback'}
      badge={feedbackCount}
      color="#FF9800"
    />
    <Tab 
      label="问答" 
      active={category === 'question'}
      badge={questionCount}
      color="#2196F3"
    />
  </CategoryTabs>
  
  {/* 消息列表 */}
  <FlatList
    data={filteredMessages}
    renderItem={({item}) => <TemporaryMessageItem message={item} />}
    keyExtractor={item => item.id}
    emptyComponent={
      <EmptyState 
        title="暂无消息"
        description="徒步中的求救、路况、问答将显示在这里"
      />
    }
  />
  
  {/* 底部提示 */}
  <FooterNotice>
    <Icon name="clock.arrow.circlepath" size={16} color="#757575" />
    <Text style={{color: '#757575', fontSize: 12}}>
      本次徒步结束后，这些消息将归档到历史记录，无法继续联系
    </Text>
  </FooterNotice>
</TemporaryMessages>
```

### 3.5 页面：临时聊天页 (TemporaryChat)

**页面路由**: `/messages/temporary/:userId`

```typescript
<TemporaryChatPage>
  <Header 
    title={user.nickname}
    subtitle={`距离您 ${formatDistance(user.distance)} · 路线相似度 ${user.routeSimilarity}%`}
    rightButton={{icon: 'info.circle', onPress: showUserInfo}}
  />
  
  {/* 警告横幅 */}
  <WarningBanner>
    <Icon name="exclamationmark.triangle.fill" color="#FF9800" />
    <Text>临时会话 - 本次徒步结束后将无法继续发送消息</Text>
  </WarningBanner>
  
  <GiftedChat
    messages={messages}
    onSend={handleSend}
    user={{_id: currentUserId}}
    // 禁止发送语音、视频等，仅文字和图片
  />
  
  {/* 合拍按钮 */}
  <SnapButton 
    onPress={handleSnap}
    alreadySnapped={hasSnapped}
    mutualSnap={isMutualSnap}
  >
    {isMutualSnap ? (
      <>
        <Icon name="checkmark.circle.fill" color="#4CAF50" />
        <Text>已成为好友</Text>
      </>
    ) : hasSnapped ? (
      <>
        <Icon name="clock.fill" color="#FF9800" />
        <Text>等待对方合拍</Text>
      </>
    ) : (
      <>
        <Icon name="hand.thumbsup.fill" />
        <Text>合拍</Text>
      </>
    )}
  </SnapButton>
</TemporaryChatPage>
```

**合拍逻辑**:
```typescript
const handleSnap = async () => {
  if (hasSnapped) return;
  
  await api.post('/snap', {targetUserId: user.id, hikeId: currentHike.hikeId});
  setHasSnapped(true);
  
  // 检查是否互拍
  const status = await api.get('/snap/status', {userId: user.id});
  if (status.isMutual) {
    setIsMutualSnap(true);
    showToast('你们已成为好友！现在可以在好友列表中聊天');
    // 发送系统消息到聊天中
  }
};
```

---

## 四、Tab: 设置

### 4.1 页面：设置主页 (SettingsMain)

**页面路由**: `/settings`

```typescript
<SettingsMainPage>
  <Header title="设置" />
  
  <ScrollView>
    {/* 用户信息卡片 */}
    <UserCard onPress={navigateToProfile}>
      <Avatar source={user.avatar} size={64} />
      <UserInfo>
        <Name>{user.nickname}</Name>
        <Text style={{color: '#757575'}}>{user.phone || '微信用户'}</Text>
      </UserInfo>
      <Icon name="chevron.right" color="#BDBDBD" />
    </UserCard>
    
    <Section>
      <SectionHeader>隐私与安全</SectionHeader>
      <Cell 
        title="隐私设置"
        icon="eye.fill"
        iconColor="#2196F3"
        onPress={() => navigate('/settings/privacy')}
        accessory="disclosure"
      />
      <Cell 
        title="账号与安全"
        icon="lock.shield.fill"
        iconColor="#4CAF50"
        onPress={() => navigate('/settings/account')}
        accessory="disclosure"
      />
    </Section>
    
    <Section>
      <SectionHeader>偏好设置</SectionHeader>
      <Cell 
        title="语言"
        icon="globe"
        iconColor="#9C27B0"
        value={language === 'zh-CN' ? '简体中文' : 'English'}
        onPress={() => navigate('/settings/language')}
        accessory="disclosure"
      />
      <Cell 
        title="地图设置"
        icon="map.fill"
        iconColor="#FF9800"
        onPress={() => navigate('/settings/map')}
        accessory="disclosure"
      />
      <Cell 
        title="通知设置"
        icon="bell.fill"
        iconColor="#D32F2F"
        onPress={() => navigate('/settings/notifications')}
        accessory="disclosure"
      />
    </Section>
    
    <Section>
      <SectionHeader>关于</SectionHeader>
      <Cell 
        title="使用指南"
        icon="book.fill"
        iconColor="#03A9F4"
        onPress={() => navigate('/settings/guide')}
        accessory="disclosure"
      />
      <Cell 
        title="安全提示"
        icon="exclamationmark.shield.fill"
        iconColor="#FF5722"
        onPress={() => navigate('/settings/safety')}
        accessory="disclosure"
      />
      <Cell 
        title="关于我们"
        icon="info.circle.fill"
        iconColor="#757575"
        value={`版本 ${appVersion}`}
        onPress={() => navigate('/settings/about')}
        accessory="disclosure"
      />
    </Section>
    
    {/* 危险操作区 */}
    <DangerZone>
      <Button 
        title="退出登录"
        onPress={logout}
        variant="outline"
        color="#D32F2F"
      />
    </DangerZone>
  </ScrollView>
</SettingsMainPage>
```

### 4.2 页面：隐私设置 (PrivacySettings)

**页面路由**: `/settings/privacy`

```typescript
<PrivacySettingsPage>
  <Header title="隐私设置" />
  
  <ScrollView>
    {/* 地图可见性 */}
    <Section>
      <SectionHeader>位置可见性</SectionHeader>
      <Cell 
        title="在地图上显示我的位置"
        subtitle="关闭后其他人无法在地图上看到您"
        accessory={
          <Switch 
            value={privacy.visibleOnMap}
            onValueChange={toggleVisibleOnMap}
          />
        }
      />
      
      {privacy.visibleOnMap && (
        <RangeSelector>
          <SectionFooter>可见范围</SectionFooter>
          <SegmentedControl
            values={['1公里', '3公里', '5公里', '10公里']}
            selectedIndex={[1,3,5,10].indexOf(privacy.visibleRange)}
            onChange={(index) => setVisibleRange([1,3,5,10][index])}
          />
          <RangeVisualization 
            currentRange={privacy.visibleRange}
            userLocation={currentLocation}
          />
        </RangeSelector>
      )}
    </Section>
    
    {/* 接收设置 */}
    <Section>
      <SectionHeader>接收设置</SectionHeader>
      <Cell 
        title="接收求救信息"
        subtitle="附近有用户求救时通知我（推荐开启）"
        icon="sos"
        iconColor="#D32F2F"
        accessory={
          <Switch 
            value={privacy.receiveSOS}
            onValueChange={toggleReceiveSOS}
          />
        }
      />
      <Cell 
        title="接收周围提问"
        subtitle="允许相似路线的用户向我提问"
        icon="questionmark.bubble"
        iconColor="#2196F3"
        accessory={
          <Switch 
            value={privacy.receiveQuestions}
            onValueChange={toggleReceiveQuestions}
          />
        }
      />
      <Cell 
        title="接收路况反馈"
        subtitle="接收前方的路况信息"
        icon="exclamationmark.triangle"
        iconColor="#FF9800"
        accessory={
          <Switch 
            value={privacy.receiveFeedback}
            onValueChange={toggleReceiveFeedback}
          />
        }
      />
      
      {privacy.receiveFeedback && (
        <Cell 
          title="仅接收紧急路况"
          subtitle="仅接收道路阻断、危险区域等高风险信息"
          indentationLevel={1}
          accessory={
            <Switch 
              value={privacy.feedbackFilter === 'danger-only'}
              onValueChange={(v) => setFeedbackFilter(v ? 'danger-only' : 'all')}
            />
          }
        />
      )}
    </Section>
    
    {/* 数据管理 */}
    <Section>
      <SectionHeader>数据管理</SectionHeader>
      <Cell 
        title="清除位置历史"
        subtitle="删除所有已上传的位置记录"
        onPress={clearLocationHistory}
        accessory="disclosure"
      />
      <Cell 
        title="导出我的数据"
        subtitle="下载您在本应用的所有数据"
        onPress={exportUserData}
        accessory="disclosure"
      />
    </Section>
  </ScrollView>
</PrivacySettingsPage>
```

### 4.3 页面：账号与安全 (AccountSecurity)

**页面路由**: `/settings/account`

```typescript
<AccountSecurityPage>
  <Header title="账号与安全" />
  
  <Section>
    <Cell 
      title="手机号"
      value={user.phone || '未绑定'}
      onPress={user.phone ? changePhone : bindPhone}
      accessory="disclosure"
    />
    <Cell 
      title="微信账号"
      value={user.wechatBound ? '已绑定' : '未绑定'}
      onPress={user.wechatBound ? unbindWechat : bindWechat}
      accessory="disclosure"
    />
  </Section>
  
  <Section>
    <SectionHeader>安全设置</SectionHeader>
    <Cell 
      title="修改密码"
      onPress={changePassword}
      accessory="disclosure"
    />
    <Cell 
      title="紧急联系人"
      subtitle="设置后可在求救时同步通知"
      onPress={setEmergencyContact}
      accessory="disclosure"
    />
  </Section>
  
  <DangerZone>
    <Cell 
      title="注销账号"
      titleStyle={{color: '#D32F2F'}}
      onPress={deleteAccount}
      accessory="disclosure"
    />
  </DangerZone>
</AccountSecurityPage>
```

### 4.4 页面：语言设置 (LanguageSettings)

**页面路由**: `/settings/language`

```typescript
<LanguageSettingsPage>
  <Header title="语言" />
  
  <Section>
    <LanguageOption 
      language="zh-CN"
      label="简体中文"
      selected={currentLanguage === 'zh-CN'}
      onSelect={() => changeLanguage('zh-CN')}
      preview={{
        title: '徒步地图',
        description: '开始您的探索之旅',
        button: '开始徒步'
      }}
    />
    <LanguageOption 
      language="en"
      label="English"
      selected={currentLanguage === 'en'}
      onSelect={() => changeLanguage('en')}
      preview={{
        title: 'Hiking Map',
        description: 'Start your exploration journey',
        button: 'Start Hiking'
      }}
    />
  </Section>
  
  <SectionFooter>
    <Text>更改语言将立即生效，部分界面可能需要重启应用</Text>
    <Switch 
      label="跟随系统语言"
      value={followSystem}
      onValueChange={toggleFollowSystem}
    />
  </SectionFooter>
</LanguageSettingsPage>
```

---

## 五、核心业务流程状态机

### 5.1 徒步生命周期
```typescript
type HikingState = 
  | 'IDLE'           // 未开始，在地图页预览
  | 'STARTING'       // 点击开始，获取GPS权限中
  | 'RECORDING'      // 正常记录中
  | 'PAUSED'         // 用户主动休息/暂停
  | 'BACKGROUND'     // 后台记录中（应用切后台）
  | 'SOS_ACTIVE'     // 求救中（可与其他状态叠加）
  | 'ENDING'         // 点击结束，确认中
  | 'SAVING'         // 保存数据中
  | 'ENDED';         // 已结束，可查看历史

// 状态转换
const transitions = {
  'IDLE': ['STARTING'],
  'STARTING': ['RECORDING', 'IDLE'], // 成功或失败
  'RECORDING': ['PAUSED', 'BACKGROUND', 'SOS_ACTIVE', 'ENDING'],
  'PAUSED': ['RECORDING', 'ENDING'],
  'BACKGROUND': ['RECORDING', 'SOS_ACTIVE', 'ENDING'],
  'SOS_ACTIVE': ['RECORDING', 'ENDING'], // 取消求救或结束徒步
  'ENDING': ['SAVING', 'RECORDING'], // 确认结束或取消
  'SAVING': ['ENDED'],
  'ENDED': ['IDLE'], // 重新开始
};
```

### 5.2 求救流程
```typescript
type SOSState = 
  | 'INACTIVE'
  | 'TRIGGERING'     // 长按求救按钮中，显示进度
  | 'CONFIRMING'     // 二次确认弹窗
  | 'SENDING'        // 发送请求中
  | 'ACTIVE'         // 求救已发出，等待响应
  | 'UPDATING'       // 更新信息中
  | 'RESCUED'        // 已被救援（手动标记）
  | 'CANCELLED'      // 取消求救
  | 'AUTO_CANCELLED'; // 自动取消（如已脱险且长时间无更新）

// 核心逻辑
async function triggerSOS() {
  // 1. 获取当前位置
  const location = await getCurrentLocation();
  
  // 2. 查询周围用户（按距离排序）
  const nearbyUsers = await fetchNearbyUsers({
    center: location,
    radius: 10000, // 10km内
    limit: 10,
    filter: 'receiveSOS' // 只取开启接收求救的用户
  });
  
  // 3. 选择最近的3个
  const recipients = nearbyUsers.slice(0, 3);
  
  // 4. 创建SOS记录
  const sos = await api.post('/sos/create', {
    location,
    recipients: recipients.map(r => r.id),
    timestamp: Date.now(),
    status: 'ACTIVE'
  });
  
  // 5. 推送通知
  await Promise.all(recipients.map(r => 
    pushNotification(r.id, {
      type: 'SOS',
      title: '附近有用户求救！',
      body: `距离您 ${formatDistance(r.distance)}，点击查看详情`,
      data: {sosId: sos.id, location}
    })
  ));
  
  // 6. 本地状态更新
  setSOSStatus({isActive: true, sosId: sos.id, recipients});
}
```

---

## 六、技术实现要点

### 6.1 高德地图集成要求
```typescript
// 地图配置
const mapConfig = {
  key: 'YOUR_AMAP_KEY',
  plugin: [
    'AMap.Geolocation',      // 定位
    'AMap.Geocoder',         // 逆地理编码
    'AMap.GraspRoad',        // 轨迹纠偏
    'AMap.MarkerClusterer',  // 点聚合
  ],
  viewMode: '2D', // 户外场景2D更清晰
  zooms: [3, 20],
  defaultZoom: 16,
};

// 自定义地图样式（户外主题）
const customMapStyle = {
  styleJson: [
    // 强调自然地貌，淡化人工建筑
    {featureType: 'water', elementType: 'geometry', stylers: {color: '#B3E5FC'}},
    {featureType: 'green', elementType: 'geometry', stylers: {color: '#C8E6C9'}},
    {featureType: 'building', elementType: 'geometry', stylers: {visibility: 'off'}},
    {featureType: 'road', elementType: 'geometry', stylers: {color: '#FFFFFF', weight: 2}},
  ]
};
```

### 6.2 后台定位策略
```typescript
// React Native / Flutter 实现
const backgroundGeolocationConfig = {
  desiredAccuracy: BackgroundGeolocation.DESIRED_ACCURACY_HIGH,
  distanceFilter: 10, // 每10米记录一个点
  stopTimeout: 5, // 停止5分钟后停止记录
  debug: false,
  logLevel: BackgroundGeolocation.LOG_LEVEL_VERBOSE,
  stopOnTerminate: false, // 应用被杀死后继续记录（需引导用户开启权限）
  startOnBoot: false,
  notification: {
    title: '正在记录徒步路线',
    text: '保持应用运行以确保持续记录位置',
  },
  // 电量优化
  disableElasticity: false,
  elasticityMultiplier: 2,
  // 轨迹纠偏
  useSignificantChangesOnly: false,
  pausesLocationUpdatesAutomatically: false,
};
```

### 6.3 用户聚合算法（后端）
```typescript
// 基于地理位置和路线相似度的聚合
function clusterUsers(users: User[]) {
  // 第一步：地理空间网格聚合（Geohash精度6位，约±0.6km）
  const geoClusters = groupByGeohash(users, precision: 6);
  
  // 第二步：路线相似度计算（DBSCAN算法变体）
  return geoClusters.map(cluster => {
    const routeClusters = dbscan(cluster.users, {
      epsilon: 0.3, // 路线相似度阈值（0-1）
      minPoints: 1,
      distanceFunction: (u1, u2) => calculateRouteSimilarity(u1.route, u2.route)
    });
    
    return routeClusters.map((routeCluster, index) => ({
      regionId: `${cluster.geohash}-${index}`,
      users: routeCluster,
      center: calculateCenter(routeCluster.map(u => u.location)),
      bounds: calculateBounds(routeCluster.map(u => u.location)),
      commonRoute: extractCommonRoute(routeCluster.map(u => u.route))
    }));
  });
}

// 路线相似度计算（简化版）
function calculateRouteSimilarity(route1: Coordinate[], route2: Coordinate[]): number {
  // 1. 采样归一化（每100米取一个点）
  const sample1 = resampleRoute(route1, interval: 100);
  const sample2 = resampleRoute(route2, interval: 100);
  
  // 2. 计算Frechet距离或Hausdorff距离
  const distance = frechetDistance(sample1, sample2);
  
  // 3. 转换为相似度（0-1）
  return 1 / (1 + distance / 1000); // 归一化
}
```

---

## 七、页面路由总表

| 路由路径                      | 页面名称     | 参数            | 说明                           |
| ----------------------------- | ------------ | --------------- | ------------------------------ |
| `/hiking/map`                 | 徒步地图     | -               | 核心页面，支持状态切换         |
| `/hiking/sos-detail`          | 求救详情     | `sosId?`        | 无参数为新建，有参数为更新     |
| `/hiking/feedback`            | 路线反馈     | -               | Modal或独立页                  |
| `/hiking/ask`                 | 向他人提问   | `targetUserId?` | 无参数为广播，有参数为指定用户 |
| `/hiking/history`             | 历史徒步列表 | -               | -                              |
| `/hiking/history/:hikeId`     | 历史详情     | `hikeId`        | -                              |
| `/messages`                   | 消息中心     | `tab?`          | 默认friends，可选temporary     |
| `/messages/friend/:friendId`  | 好友聊天     | `friendId`      | -                              |
| `/messages/temporary/:userId` | 临时聊天     | `userId`        | 仅在徒步中可访问               |
| `/settings`                   | 设置主页     | -               | -                              |
| `/settings/privacy`           | 隐私设置     | -               | -                              |
| `/settings/account`           | 账号安全     | -               | -                              |
| `/settings/language`          | 语言设置     | -               | -                              |
| `/settings/map`               | 地图设置     | -               | 地图类型、离线地图等           |
| `/settings/notifications`     | 通知设置     | -               | -                              |
| `/settings/guide`             | 使用指南     | -               | -                              |
| `/settings/safety`            | 安全提示     | -               | -                              |
| `/settings/about`             | 关于我们     | -               | -                              |
| `/login`                      | 登录页       | -               | 初始进入或退出后               |
| `/onboarding`                 | 引导页       | -               | 首次安装                       |

---

这份设计文档涵盖了完整的UI结构、交互逻辑、数据定义和技术实现要点。
