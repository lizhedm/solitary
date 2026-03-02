##### 原始需求

##### 1、开始徒步后时间开始计算，点击暂停后时间暂停（按钮变成继续），可点击继续后时间继续计算。点击结束后，本次徒步完成，记录本次徒步数据到“徒步历史”页面中，
2、长按SOS按钮后，增加长按的动画。长按时间到后进入求救详情页面。
3、在“消息中心”，增加1个tab：“我发布的路况”（“发布路况信息”页面中，我发布成功的历史路况信息会出现在这个tab）
4、“消息中心”的“临时会话”tab中，分为两种消息：1️⃣别人单独发给我的单条消息；2️⃣我在“向周围人提问“中，发布成功的历史提问消息，这类消息进行折叠。例如这条提问消息发送给了8个其他用户，则这条消息在“临时会话”中只展示为一条，点击这一条后进入到分别和8个人的消息对话列表中，分别点击可以再进入和某个用户的具体对话中。
5、“徒步历史”页面中，打开”徒步详情“后，增加展示“徒步消息”，点击可以进入到这一次历史徒步中的临时会话消息。这些历史的临时会话消息不可以再点击发送消息，但可以点击“合拍”按钮。表示对该用户合拍，如果该用户也对我点击了“合拍”，则这两个用户关系从临时会话，转变为好友消息。
6、按照之前的需求要求，完善输出“设置”中的“隐私设置”、“账号与安全”、“语言”、“地图设置”、“通知设置”、“使用指南”、“关于我们”这几个功能。



---

## PRD v1.0.1

---

## 一、全局状态更新

### 1.1 扩展全局状态定义
```typescript
interface GlobalState {
  // ... 原有状态 ...
  
  // 新增：路况反馈状态
  myFeedbacks: Array<RouteFeedback>;
  
  // 新增：提问消息聚合状态
  myQuestions: Array<AggregatedQuestion>;
  
  // 修改：临时消息分类
  temporaryMessages: {
    directMessages: Array<DirectMessage>;      // 别人单独发给我的
    questionThreads: Array<QuestionThread>;    // 我发布的提问（聚合展示）
  };
  
  // 新增：徒步历史详情查看状态
  historyViewState: {
    currentHikeId: string | null;
    canSendMessage: boolean;  // 历史徒步不可发送，仅查看
  };
}

interface AggregatedQuestion {
  questionId: string;
  content: string;
  sentAt: number;
  recipientCount: number;
  respondents: Array<{
    userId: string;
    nickname: string;
    avatar: string;
    hasReply: boolean;
    unreadCount: number;
  }>;
}

interface QuestionThread {
  questionId: string;
  questionContent: string;
  sentAt: number;
  totalRecipients: number;
  conversations: Array<{
    userId: string;
    messages: Array<Message>;
    lastMessageAt: number;
    unreadCount: number;
  }>;
}
```

---

## 二、Tab: 开始徒步 - 功能完善

### 2.1 徒步计时器系统（优化版）

**状态机定义**：
```typescript
type TimerState = 'IDLE' | 'RUNNING' | 'PAUSED';

interface HikingTimer {
  state: TimerState;
  startTime: number | null;        // 本次开始时间点
  totalDuration: number;           // 累计时长（毫秒）
  pauseStartTime: number | null;   // 暂停开始时间
  displayTime: string;             // 格式化显示 "00:12:45"
}
```

**计时逻辑**：
```typescript
// 时间计算算法
function calculateDisplayTime(timer: HikingTimer): string {
  if (timer.state === 'IDLE') return '00:00:00';
  
  let elapsed = timer.totalDuration;
  
  if (timer.state === 'RUNNING' && timer.startTime) {
    elapsed += Date.now() - timer.startTime;
  }
  
  // 格式化为 HH:MM:SS
  const hours = Math.floor(elapsed / 3600000);
  const minutes = Math.floor((elapsed % 3600000) / 60000);
  const seconds = Math.floor((elapsed % 60000) / 1000);
  
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
}

// 等宽数字字体（保持显示稳定）
// fontFamily: 'Roboto Mono' 或 SF Mono, fontVariant: ['tabular-nums']
```

**底部控制栏状态切换**：

| 状态   | 左侧按钮             | 中间SOS | 右侧按钮             |
| ------ | -------------------- | ------- | -------------------- |
| 运行中 | 暂停 ⏸️ (黄色#FF9800) | SOS 🔴   | 结束 ⏹️ (灰色#757575) |
| 已暂停 | 继续 ▶️ (绿色#4CAF50) | SOS 🔴   | 结束 ⏹️ (灰色#757575) |

```typescript
// 按钮组件详细定义
<BottomControlBar>
  <LeftButton 
    onPress={timer.state === 'RUNNING' ? pauseHiking : resumeHiking}
    style={{
      backgroundColor: timer.state === 'RUNNING' ? '#FFF3E0' : '#E8F5E9',
      borderColor: timer.state === 'RUNNING' ? '#FF9800' : '#4CAF50',
      borderWidth: 2,
    }}
  >
    <Icon 
      name={timer.state === 'RUNNING' ? 'pause.fill' : 'play.fill'} 
      color={timer.state === 'RUNNING' ? '#FF9800' : '#4CAF50'}
      size={28}
    />
    <Text style={{color: timer.state === 'RUNNING' ? '#FF9800' : '#4CAF50'}}>
      {timer.state === 'RUNNING' ? '暂停' : '继续'}
    </Text>
  </LeftButton>
  
  <SOSButton onLongPress={handleSOSLongPress} />
  
  <RightButton onPress={confirmEndHiking}>
    <Icon name="stop.fill" color="#757575" size={28} />
    <Text style={{color: '#757575'}}>结束</Text>
  </RightButton>
</BottomControlBar>
```

**结束徒步确认弹窗**：
```typescript
<EndHikingConfirmModal>
  <ModalTitle>结束本次徒步？</ModalTitle>
  <ModalContent>
    <StatRow>
      <Stat label="时长" value={currentDuration} />
      <Stat label="距离" value={`${(distance/1000).toFixed(2)}km`} />
      <Stat label="轨迹点" value={coordinates.length} />
    </StatRow>
    <WarningText>结束后数据将保存到徒步历史，无法继续记录</WarningText>
  </ModalContent>
  <ModalActions>
    <Button title="取消" variant="outline" onPress={closeModal} />
    <Button 
      title="确认结束" 
      variant="primary" 
      onPress={finalizeHiking}
      style={{backgroundColor: '#D32F2F'}}
    />
  </ModalActions>
</EndHikingConfirmModal>
```

**数据保存逻辑**：
```typescript
async function finalizeHiking() {
  // 1. 停止定位服务
  await stopLocationTracking();
  
  // 2. 构建徒步记录
  const hikeRecord = {
    id: generateUUID(),
    startTime: hikeState.startTime,
    endTime: Date.now(),
    duration: timer.totalDuration,
    distance: calculateTotalDistance(coordinates),
    coordinates: compressCoordinates(coordinates), // 压缩存储
    altitudeData: altitudeRecords,
    startLocation: await reverseGeocode(coordinates[0]),
    endLocation: await reverseGeocode(coordinates[coordinates.length - 1]),
    messageCount: temporaryMessages.length,
    snapshot: await generateMapSnapshot(coordinates), // 地图缩略图
  };
  
  // 3. 保存到本地存储
  await saveToLocalStorage('hiking_history', hikeRecord);
  
  // 4. 同步到云端（异步）
  syncToCloud(hikeRecord).catch(console.error);
  
  // 5. 清空当前徒步状态
  resetHikingState();
  
  // 6. 跳转到历史记录页或显示完成弹窗
  navigate('/hiking/history', {highlight: hikeRecord.id});
}
```

---

### 2.2 SOS长按动画与交互

**交互流程**：
```
用户手指按下 → 显示进度环动画(0-100%) → 达到阈值(800ms) → 触发完成 → 跳转页面
                ↓ 中途松开
              取消触发，进度环回弹消失
```

**组件实现**：
```typescript
interface SOSButtonProps {
  onLongPressComplete: () => void;
  minPressDuration: number; // 800ms
}

const SOSButton: React.FC<SOSButtonProps> = ({ onLongPressComplete }) => {
  const [pressProgress, setPressProgress] = useState(0);
  const [isPressing, setIsPressing] = useState(false);
  const pressStartTime = useRef<number>(0);
  const animationFrame = useRef<number>();
  
  const handlePressIn = () => {
    setIsPressing(true);
    pressStartTime.current = Date.now();
    
    const animate = () => {
      const elapsed = Date.now() - pressStartTime.current;
      const progress = Math.min(elapsed / 800, 1);
      setPressProgress(progress);
      
      if (progress < 1) {
        animationFrame.current = requestAnimationFrame(animate);
      } else {
        // 达到阈值，触发完成
        onLongPressComplete();
        resetPressState();
      }
    };
    
    animate();
  };
  
  const handlePressOut = () => {
    if (animationFrame.current) {
      cancelAnimationFrame(animationFrame.current);
    }
    // 未达阈值，回弹动画
    if (pressProgress < 1) {
      Animated.spring(pressProgressAnim, {
        toValue: 0,
        useNativeDriver: true,
        friction: 5,
      }).start();
    }
    setIsPressing(false);
  };
  
  return (
    <SOSButtonContainer
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      activeOpacity={1}
    >
      {/* 外圈进度环 */}
      <ProgressRing 
        progress={pressProgress}
        radius={50}
        strokeWidth={6}
        color="#FFCDD2"
        backgroundColor="#B71C1C"
      />
      
      {/* 内圈按钮 */}
      <SOSInnerCircle style={{
        transform: [{ scale: 1 + pressProgress * 0.1 }], // 按压放大效果
        backgroundColor: `rgba(211, 47, 47, ${1 - pressProgress * 0.3})`, // 变亮
      }}>
        <Icon name="exclamationmark.triangle.fill" size={36} color="#FFF" />
        <Text style={{color: '#FFF', fontWeight: 'bold', fontSize: 14}}>SOS</Text>
      </SOSInnerCircle>
      
      {/* 提示文字 */}
      {isPressing && pressProgress < 0.3 && (
        <PressHint>长按求救</PressHint>
      )}
    </SOSButtonContainer>
  );
};
```

**进度环组件**：
```typescript
const ProgressRing: React.FC<{
  progress: number;
  radius: number;
  strokeWidth: number;
  color: string;
}> = ({ progress, radius, strokeWidth, color }) => {
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference * (1 - progress);
  
  return (
    <Svg width={radius * 2 + strokeWidth} height={radius * 2 + strokeWidth}>
      <Circle
        cx={radius + strokeWidth/2}
        cy={radius + strokeWidth/2}
        r={radius}
        fill="none"
        stroke={color}
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeDasharray={circumference}
        strokeDashoffset={strokeDashoffset}
        transform={`rotate(-90, ${radius + strokeWidth/2}, ${radius + strokeWidth/2})`}
      />
    </Svg>
  );
};
```

**跳转后的求救详情页**：
- 自动填充当前位置
- 显示已通知的用户数量（正在查询中...）
- 表单字段见后续章节

---

## 三、Tab: 消息中心 - 重构设计

### 3.1 消息中心整体架构

**Tab结构（4个）**：
```
┌─────────────────────────────────────────────────────────────┐
│  [好友消息]    [临时会话]    [我发布的路况]    [我发布的提问]   │
│                                                             │
│  永久好友聊天   徒步相关临时消息  我发布的路况历史   我发起的提问聚合 │
│  列表+对话页    单条消息+聚合    列表+详情+失效管理  聚合列表+分支对话 │
└─────────────────────────────────────────────────────────────┘
```

**空状态处理**：
- 无进行中的徒步时，"临时会话"、"我发布的路况"、"我发布的提问"显示空状态："开始徒步后即可使用此功能"

### 3.2 Tab 1: 好友消息（原有功能优化）

**列表项增加最后消息预览**：
```typescript
<FriendListItem>
  <Avatar source={friend.avatar} size={50} />
  <Content>
    <NameRow>
      <Nickname>{friend.nickname}</Nickname>
      <Time>{formatRelativeTime(friend.lastMessageTime)}</Time>
    </NameRow>
    <PreviewRow>
      <LastMessage numberOfLines={1}>
        {friend.lastMessageType === 'image' ? '[图片]' : friend.lastMessageContent}
      </LastMessage>
      {friend.unreadCount > 0 && <Badge count={friend.unreadCount} />}
    </PreviewRow>
  </Content>
</FriendListItem>
```

### 3.3 Tab 2: 临时会话（重构）

**数据结构**：
```typescript
interface TemporaryMessageItem {
  id: string;
  type: 'DIRECT' | 'QUESTION_AGGREGATED';
  // DIRECT: 别人单独发给我的
  // QUESTION_AGGREGATED: 我发布的提问聚合
  
  // 公共字段
  unreadCount: number;
  lastMessageAt: number;
  
  // DIRECT特有
  sender?: {
    userId: string;
    nickname: string;
    avatar: string;
    distance: number; // 发送时的距离
  };
  lastMessage?: {
    content: string;
    type: 'text' | 'image';
  };
  
  // QUESTION_AGGREGATED特有
  question?: {
    questionId: string;
    content: string;
    sentAt: number;
    recipientCount: number;      // 发送给N人
    responseCount: number;       // N人已回复
    respondentAvatars: string[]; // 回复者头像缩略（最多3个）
  };
}
```

**列表UI**：

**类型A：直接消息（单条）**
```typescript
<DirectMessageItem onPress={() => navigateToDirectChat(item.sender.userId)}>
  <Avatar source={item.sender.avatar} size={50} />
  <Content>
    <NameRow>
      <Nickname>{item.sender.nickname}</Nickname>
      <DistanceTag>{formatDistance(item.sender.distance)}</DistanceTag>
      <Time>{formatTime(item.lastMessageAt)}</Time>
    </NameRow>
    <PreviewRow>
      <MessagePreview>{item.lastMessage.content}</MessagePreview>
      {item.unreadCount > 0 && <Badge count={item.unreadCount} />}
    </PreviewRow>
  </Content>
  <WarningTag>临时</WarningTag>
</DirectMessageItem>
```

**类型B：提问聚合（折叠）**
```typescript
<QuestionAggregatedItem onPress={() => navigateToQuestionBranches(item.question.questionId)}>
  <IconContainer backgroundColor="#E3F2FD">
    <Icon name="questionmark.bubble.fill" color="#2196F3" size={24} />
  </IconContainer>
  <Content>
    <NameRow>
      <Title>我的提问</Title>
      <Time>{formatTime(item.question.sentAt)}</Time>
    </NameRow>
    <QuestionContent numberOfLines={1}>
      {item.question.content}
    </QuestionContent>
    <MetaRow>
      <RecipientInfo>
        <Text>发送给 {item.question.recipientCount} 人</Text>
        {item.question.responseCount > 0 && (
          <ResponseBadge>
            <AvatarGroup 
              avatars={item.question.respondentAvatars} 
              max={3} 
              size={20} 
            />
            <Text>{item.question.responseCount} 人已回复</Text>
          </ResponseBadge>
        )}
      </RecipientInfo>
      {item.unreadCount > 0 && <Badge count={item.unreadCount} />}
    </MetaRow>
  </Content>
  <ChevronRightIcon />
</QuestionAggregatedItem>
```

**点击聚合项后的分支列表页**：
```typescript
<QuestionBranchesPage>
  <Header 
    title="提问回复" 
    subtitle={question.content}
    onBack={() => navigateBack()}
  />
  
  <InfoBanner>
    <Icon name="info.circle.fill" color="#2196F3" />
    <Text>发送给 {totalRecipients} 人 · {respondents.length} 人回复</Text>
  </InfoBanner>
  
  <SectionList
    sections={[
      {
        title: '已回复',
        data: respondents.filter(r => r.hasReply),
        renderItem: ({item}) => <RespondentRow respondent={item} hasReply={true} />
      },
      {
        title: '未回复',
        data: respondents.filter(r => !r.hasReply),
        renderItem: ({item}) => <RespondentRow respondent={item} hasReply={false} />
      }
    ]}
  />
</QuestionBranchesPage>

// 分支列表项
<RespondentRow onPress={() => navigateToBranchChat(respondent.userId)}>
  <Avatar source={respondent.avatar} size={48} />
  <Content>
    <Nickname>{respondent.nickname}</Nickname>
    {hasReply ? (
      <LastReply numberOfLines={1}>{respondent.lastMessage}</LastReply>
    ) : (
      <NoReplyHint>等待回复中...</NoReplyHint>
    )}
  </Content>
  {respondent.unreadCount > 0 && <Badge count={respondent.unreadCount} />}
  <Time>{formatTime(respondent.lastMessageAt)}</Time>
</RespondentRow>
```

### 3.4 Tab 3: 我发布的路况（新增）

**数据结构**：
```typescript
interface MyFeedbackItem {
  id: string;
  type: 'blocked' | 'detour' | 'weather' | 'water' | 'campsite' | 'viewpoint' | 'danger' | 'other';
  content: string;
  location: {lat: number; lng: number; address: string};
  photos: string[];
  createdAt: number;
  validity: number | 'endOfDay' | 'permanent'; // 有效期
  status: 'ACTIVE' | 'EXPIRED' | 'CANCELLED';
  viewCount: number;      // 被查看次数
  confirmCount: number;   // 被确认有用次数
  commentCount: number;   // 收到的评论数
}
```

**列表UI**：
```typescript
<MyFeedbackList>
  <FilterTabs 
    options={['全部', '生效中', '已过期']}
    selected={filter}
    onSelect={setFilter}
  />
  
  <FlatList
    data={filteredFeedbacks}
    renderItem={({item}) => <FeedbackHistoryCard item={item} />}
  />
</MyFeedbackList>

// 卡片组件
<FeedbackHistoryCard>
  <CardHeader>
    <TypeTag type={item.type} />
    <StatusBadge status={item.status} />
    <Time>{formatTime(item.createdAt)}</Time>
  </CardHeader>
  
  <ContentText numberOfLines={2}>{item.content}</ContentText>
  
  {item.photos.length > 0 && (
    <PhotoThumbnailRow>
      {item.photos.slice(0, 3).map(photo => (
        <Thumbnail key={photo} source={photo} />
      ))}
      {item.photos.length > 3 && (
        <MoreOverlay>+{item.photos.length - 3}</MoreOverlay>
      )}
    </PhotoThumbnailRow>
  )}
  
  <LocationRow>
    <Icon name="mappin" size={14} color="#757575" />
    <Text style={{color: '#757575', fontSize: 12}}>{item.location.address}</Text>
  </LocationRow>
  
  <CardFooter>
    <StatItem icon="eye" value={item.viewCount} label="查看" />
    <StatItem icon="hand.thumbsup" value={item.confirmCount} label="确认" />
    <StatItem icon="bubble.left" value={item.commentCount} label="评论" />
    
    {item.status === 'ACTIVE' && (
      <ActionButton onPress={() => cancelFeedback(item.id)}>
        撤销
      </ActionButton>
    )}
  </CardFooter>
</FeedbackHistoryCard>
```

**详情页**：
```typescript
<FeedbackDetailPage>
  <Header title="路况详情" />
  
  <StaticMap 
    center={feedback.location}
    marker={feedback.location}
    readOnly={true}
  />
  
  <ContentSection>
    <TypeTag large type={feedback.type} />
    <Time>{formatFullTime(feedback.createdAt)}</Time>
    <Text style={{fontSize: 16, lineHeight: 24}}>{feedback.content}</Text>
  </ContentSection>
  
  {feedback.photos.length > 0 && (
    <PhotoGallery photos={feedback.photos} />
  )}
  
  <EffectivenessSection>
    <SectionTitle>有效性</SectionTitle>
    <ProgressBar 
      label="查看" 
      value={feedback.viewCount} 
      total={feedback.recipientCount} 
    />
    <ProgressBar 
      label="确认有用" 
      value={feedback.confirmCount} 
      total={feedback.viewCount} 
    />
  </EffectivenessSection>
  
  <CommentsSection>
    <SectionTitle>收到的评论</SectionTitle>
    {/* 评论列表 */}
  </CommentsSection>
</FeedbackDetailPage>
```

### 3.5 Tab 4: 我发布的提问（新增）

与3.3节的聚合展示类似，但此Tab专门展示我发布的所有提问历史，按时间倒序排列。

---

## 四、徒步历史与详情

### 4.1 徒步历史列表页

**优化项**：
- 增加月份分组
- 增加统计卡片（本月徒步次数/总距离）

```typescript
<HikingHistoryPage>
  <SummaryCard>
    <StatBox label="本月徒步" value={`${monthlyCount}次`} />
    <StatBox label="本月距离" value={`${monthlyDistance}km`} />
    <StatBox label="累计次数" value={totalCount} />
  </SummaryCard>
  
  <SectionList
    sections={groupByMonth(historyItems)}
    renderSectionHeader={({section}) => (
      <SectionHeader>{section.title}</SectionHeader>
    )}
    renderItem={({item}) => <HistoryCard item={item} />}
  />
</HikingHistoryPage>
```

### 4.2 徒步详情页（关键更新）

**新增：徒步消息入口**

```typescript
<HikingDetailPage>
  {/* ... 原有内容：地图、统计、海拔图 ... */}
  
  {/* 新增：消息回顾入口 */}
  <Section title="本次徒步消息">
    <MessageSummaryCard onPress={openHistoryMessages}>
      <IconContainer backgroundColor="#E3F2FD">
        <Icon name="bubble.left.and.bubble.right.fill" color="#2196F3" />
      </IconContainer>
      <Content>
        <Title>查看临时会话</Title>
        <Subtitle>
          {messageCount > 0 
            ? `${messageCount} 条消息 · ${participantCount} 人参与`
            : '本次徒步没有消息记录'
          }
        </Subtitle>
      </Content>
      <ChevronRightIcon />
    </MessageSummaryCard>
  </Section>
  
  {/* ... 合拍好友列表 ... */}
</HikingDetailPage>
```

### 4.3 历史消息查看页（新增）

**核心特性**：只读模式 + 合拍功能

```typescript
<HistoryMessagesPage>
  <Header 
    title="历史消息" 
    subtitle="本次徒步的临时会话记录"
  />
  
  <ReadOnlyBanner>
    <Icon name="clock.arrow.circlepath" color="#FF9800" />
    <Text>历史消息，无法继续发送</Text>
  </ReadOnlyBanner>
  
  <ParticipantList>
    {participants.map(participant => (
      <ParticipantRow key={participant.userId}>
        <Avatar source={participant.avatar} size={50} />
        <Content>
          <Nickname>{participant.nickname}</Nickname>
          <MessageCount>{participant.messageCount} 条对话</MessageCount>
        </Content>
        
        {/* 合拍按钮 - 核心功能 */}
        <SnapButton 
          onPress={() => handleSnap(participant.userId)}
          status={participant.snapStatus}
          disabled={participant.snapStatus === 'MUTUAL'}
        >
          {participant.snapStatus === 'NONE' && (
            <>
              <Icon name="hand.thumbsup" size={16} />
              <Text>合拍</Text>
            </>
          )}
          {participant.snapStatus === 'PENDING' && (
            <>
              <Icon name="clock" size={16} color="#FF9800" />
              <Text style={{color: '#FF9800'}}>等待</Text>
            </>
          )}
          {participant.snapStatus === 'MUTUAL' && (
            <>
              <Icon name="checkmark.circle.fill" size={16} color="#4CAF50" />
              <Text style={{color: '#4CAF50'}}>好友</Text>
            </>
          )}
        </SnapButton>
      </ParticipantRow>
    ))}
  </ParticipantList>
  
  {/* 点击参与者查看对话记录 */}
  <Modal visible={selectedParticipant !== null}>
    <MessageHistoryView 
      messages={selectedParticipant?.messages}
      readOnly={true}
    />
  </Modal>
</HistoryMessagesPage>
```

**合拍逻辑（历史消息场景）**：
```typescript
// 与实时徒步的区别：不需要双方同时在线
async function handleSnap(targetUserId: string) {
  const result = await api.post('/snap/from-history', {
    targetUserId,
    hikeId: currentHikeId, // 标识来自哪次徒步
  });
  
  if (result.isMutual) {
    // 双方已互拍，建立好友关系
    showToast('你们已成为好友！');
    addFriend(targetUserId);
    updateSnapStatus(targetUserId, 'MUTUAL');
  } else {
    // 记录合拍意向，等待对方在历史记录中回拍
    updateSnapStatus(targetUserId, 'PENDING');
    showToast('已发送合拍请求，如果对方也拍你，将成为好友');
  }
}
```

---

## 五、设置页面详细设计

### 5.1 隐私设置（PrivacySettings）

```typescript
<PrivacySettingsPage>
  <Header title="隐私设置" />
  
  <Section header="位置可见性">
    <Cell 
      title="在地图上显示我的位置"
      accessory={<Switch value={visibleOnMap} onChange={setVisibleOnMap} />}
    />
    
    {visibleOnMap && (
      <>
        <Cell 
          title="可见范围"
          subtitle="选择多大范围内的其他用户可以看到你"
          accessory={
            <SegmentedControl 
              values={['1km', '3km', '5km', '10km']}
              selected={rangeIndex}
              onChange={setVisibleRange}
            />
          }
        />
        <MapPreview 
          center={userLocation}
          radius={visibleRange}
          description={`当前设置：周围${visibleRange}公里内的用户可以看到你`}
        />
      </>
    )}
  </Section>
  
  <Section header="接收设置">
    <Cell 
      title="接收求救信息"
      subtitle="附近有用户求救时通知我（强烈建议开启）"
      icon="sos"
      iconColor="#D32F2F"
      accessory={<Switch value={receiveSOS} onChange={setReceiveSOS} />}
    />
    <Cell 
      title="接收周围提问"
      subtitle="允许路线相似的用户向我提问"
      icon="questionmark.bubble"
      iconColor="#2196F3"
      accessory={<Switch value={receiveQuestions} onChange={setReceiveQuestions} />}
    />
    <Cell 
      title="接收路况反馈"
      subtitle="接收前方路况信息"
      icon="exclamationmark.triangle"
      iconColor="#FF9800"
      accessory={<Switch value={receiveFeedback} onChange={setReceiveFeedback} />}
    />
    {receiveFeedback && (
      <Cell 
        title="仅接收紧急路况"
        subtitle="仅接收道路阻断、危险区域等高风险信息"
        indentationLevel={1}
        accessory={
          <Switch 
            value={feedbackFilter === 'danger-only'} 
            onChange={(v) => setFeedbackFilter(v ? 'danger-only' : 'all')}
          />
        }
      />
    )}
  </Section>
  
  <Section header="数据管理">
    <Cell 
      title="清除位置历史"
      subtitle="删除所有已上传的位置记录"
      onPress={clearLocationHistory}
      accessory="disclosure"
    />
    <Cell 
      title="导出我的数据"
      subtitle="下载您在本应用的所有数据（JSON格式）"
      onPress={exportUserData}
      accessory="disclosure"
    />
    <Cell 
      title="隐身模式"
      subtitle="24小时内不显示在地图上，也不接收任何消息"
      onPress={activateGhostMode}
      accessory={<Button title="开启" size="small" />}
    />
  </Section>
</PrivacySettingsPage>
```

### 5.2 账号与安全（AccountSecurity）

```typescript
<AccountSecurityPage>
  <Header title="账号与安全" />
  
  <Section header="账号绑定">
    <Cell 
      title="手机号码"
      value={user.phone || '未绑定'}
      onPress={user.phone ? changePhone : bindPhone}
      accessory="disclosure"
    />
    <Cell 
      title="微信账号"
      value={user.wechatBound ? user.wechatNickname : '未绑定'}
      onPress={user.wechatBound ? unbindWechat : bindWechat}
      accessory={user.wechatBound ? 'disclosure' : <Button title="绑定" size="small" />}
    />
  </Section>
  
  <Section header="安全设置">
    <Cell 
      title="修改密码"
      onPress={changePassword}
      accessory="disclosure"
    />
    <Cell 
      title="紧急联系人"
      subtitle={emergencyContact ? emergencyContact.name : '设置后可在求救时短信通知'}
      onPress={setEmergencyContact}
      accessory="disclosure"
    />
    <Cell 
      title="登录设备管理"
      subtitle={`当前${deviceCount}个设备登录`}
      onPress={manageDevices}
      accessory="disclosure"
    />
  </Section>
  
  <DangerZone>
    <Cell 
      title="退出登录"
      titleStyle={{color: '#D32F2F'}}
      onPress={logout}
    />
    <Cell 
      title="注销账号"
      titleStyle={{color: '#D32F2F'}}
      subtitle="删除所有数据，不可恢复"
      onPress={deleteAccount}
    />
  </DangerZone>
</AccountSecurityPage>
```

### 5.3 语言设置（Language）

```typescript
<LanguageSettingsPage>
  <Header title="语言" />
  
  <Section>
    <LanguageOption 
      code="zh-CN"
      name="简体中文"
      selected={language === 'zh-CN'}
      onSelect={() => changeLanguage('zh-CN')}
      preview={{
        title: '徒步地图',
        description: '开始您的探索之旅',
        button: '开始徒步'
      }}
    />
    <LanguageOption 
      code="en"
      name="English"
      selected={language === 'en'}
      onSelect={() => changeLanguage('en')}
      preview={{
        title: 'Hiking Map',
        description: 'Start your exploration journey',
        button: 'Start Hiking'
      }}
    />
  </Section>
  
  <Section footer="更改语言将立即生效">
    <Cell 
      title="跟随系统语言"
      accessory={<Switch value={followSystem} onChange={setFollowSystem} />}
    />
  </Section>
</LanguageSettingsPage>
```

### 5.4 地图设置（MapSettings）

```typescript
<MapSettingsPage>
  <Header title="地图设置" />
  
  <Section header="地图显示">
    <Cell 
      title="地图类型"
      value={mapType === 'standard' ? '标准' : mapType === 'satellite' ? '卫星' : '地形'}
      onPress={selectMapType}
      accessory="disclosure"
    />
    <Cell 
      title="自动旋转"
      subtitle="根据行进方向自动旋转地图"
      accessory={<Switch value={autoRotate} onChange={setAutoRotate} />}
    />
    <Cell 
      title="保持屏幕常亮"
      subtitle="徒步过程中屏幕保持开启"
      accessory={<Switch value={keepScreenOn} onChange={setKeepScreenOn} />}
    />
  </Section>
  
  <Section header="离线地图">
    <Cell 
      title="下载离线地图"
      subtitle={`已下载 ${downloadedMaps.length} 个区域`}
      onPress={manageOfflineMaps}
      accessory="disclosure"
    />
    <Cell 
      title="自动下载常用区域"
      subtitle="WiFi下自动更新常去区域的地图"
      accessory={<Switch value={autoDownload} onChange={setAutoDownload} />}
    />
  </Section>
  
  <Section header="定位精度">
    <Cell 
      title="高精度模式"
      subtitle="更精确的位置，但耗电更快"
      accessory={
        <Checkmark selected={accuracyMode === 'high'} />
      }
      onPress={() => setAccuracyMode('high')}
    />
    <Cell 
      title="省电模式"
      subtitle="降低精度以延长续航"
      accessory={
        <Checkmark selected={accuracyMode === 'balanced'} />
      }
      onPress={() => setAccuracyMode('balanced')}
    />
  </Section>
</MapSettingsPage>
```

### 5.5 通知设置（NotificationSettings）

```typescript
<NotificationSettingsPage>
  <Header title="通知设置" />
  
  <Section header="消息通知">
    <Cell 
      title="好友消息"
      accessory={<Switch value={notifyFriendMessage} onChange={setNotifyFriendMessage} />}
    />
    <Cell 
      title="临时消息"
      subtitle="徒步中的问答和回复"
      accessory={<Switch value={notifyTempMessage} onChange={setNotifyTempMessage} />}
    />
    <Cell 
      title="求救通知"
      subtitle="附近有用户求救（建议开启）"
      accessory={<Switch value={notifySOS} onChange={setNotifySOS} />}
    />
    <Cell 
      title="路况提醒"
      subtitle="前方路况变化"
      accessory={<Switch value={notifyFeedback} onChange={setNotifyFeedback} />}
    />
  </Section>
  
  <Section header="声音与震动">
    <Cell 
      title="声音提醒"
      accessory={<Switch value={soundEnabled} onChange={setSoundEnabled} />}
    />
    <Cell 
      title="震动提醒"
      accessory={<Switch value={vibrationEnabled} onChange={setVibrationEnabled} />}
    />
    <Cell 
      title="求救特殊提醒"
      subtitle="求救通知使用特殊铃声并持续震动"
      accessory={<Switch value={sosSpecialAlert} onChange={setSosSpecialAlert} />}
    />
  </Section>
  
  <Section header="勿扰模式">
    <Cell 
      title="开启勿扰"
      subtitle="仅接收求救信息"
      accessory={<Switch value={dndEnabled} onChange={setDndEnabled} />}
    />
    {dndEnabled && (
      <Cell 
        title="勿扰时段"
        value={`${dndStartTime} - ${dndEndTime}`}
        onPress={setDndTimeRange}
        accessory="disclosure"
      />
    )}
  </Section>
</NotificationSettingsPage>
```

### 5.6 使用指南（UserGuide）

```typescript
<UserGuidePage>
  <Header title="使用指南" />
  
  <ScrollView>
    <HeroSection>
      <Icon name="map.fill" size={64} color="#2E7D32" />
      <Title>单人徒步，不再孤单</Title>
      <Subtitle>了解如何使用本应用保障安全、结识同好</Subtitle>
    </HeroSection>
    
    <GuideSection title="开始徒步">
      <GuideCard 
        icon="play.circle.fill"
        title="记录路线"
        description="点击'开始徒步'，应用将在后台记录您的行进路线，即使切换应用或锁屏也不会中断。"
      />
      <GuideCard 
        icon="pause.circle.fill"
        title="暂停与继续"
        description="休息时可以暂停计时，回来后点击继续。结束徒步后数据将自动保存。"
      />
    </GuideSection>
    
    <GuideSection title="安全保障">
      <GuideCard 
        icon="exclamationmark.triangle.fill"
        title="一键求救"
        description="长按SOS按钮3秒，您的位置和求救信息将发送给周围最近的3位用户。"
        highlight={true}
        highlightColor="#FFEBEE"
      />
      <GuideCard 
        icon="eye.fill"
        title="隐私控制"
        description="您可以在隐私设置中控制谁可以看到您，以及接收哪些类型的消息。"
      />
    </GuideSection>
    
    <GuideSection title="社交功能">
      <GuideCard 
        icon="bubble.left.and.bubble.right.fill"
        title="临时会话"
        description="徒步中可以查看周围用户，发送提问或路况信息。这些对话在徒步结束后归档。"
      />
      <GuideCard 
        icon="hand.thumbsup.fill"
        title="合拍加好友"
        description="遇到聊得来的徒步者？点击'合拍'。如果对方也拍你，你们就成为永久好友。"
      />
    </GuideSection>
    
    <GuideSection title="注意事项">
      <WarningCard 
        icon="battery.25"
        title="电量管理"
        description="持续定位会消耗电量，建议携带充电宝或开启省电模式。"
      />
      <WarningCard 
        icon="wifi.slash"
        title="离线使用"
        description="提前下载离线地图，山区可能信号不佳。"
      />
    </GuideSection>
    
    <FAQSection>
      <SectionTitle>常见问题</SectionTitle>
      <Accordion 
        items={[
          {q: '徒步中退出应用会停止记录吗？', a: '不会。开启后台定位权限后，即使退出应用或锁屏，路线记录仍会继续。'},
          {q: '别人能看到我的精确位置吗？', a: '只有在您开启"显示在地图上"且对方在您的可见范围内时，才能看到您的大致位置，不会显示精确坐标。'},
          {q: '如何删除历史记录？', a: '在"徒步历史"中左滑或长按记录项可删除。删除后不可恢复。'},
        ]}
      />
    </FAQSection>
  </ScrollView>
</UserGuidePage>
```

### 5.7 关于我们（AboutUs）

```typescript
<AboutUsPage>
  <Header title="关于我们" />
  
  <CenteredContent>
    <AppIcon size={80} />
    <AppName>徒步伴侣</AppName>
    <Version>版本 {appVersion} ({buildNumber})</Version>
    <Slogan>让每一次独行都有陪伴</Slogan>
  </CenteredContent>
  
  <Section>
    <Cell 
      title="功能介绍"
      onPress={showFeatureIntro}
      accessory="disclosure"
    />
    <Cell 
      title="用户协议"
      onPress={openUserAgreement}
      accessory="disclosure"
    />
    <Cell 
      title="隐私政策"
      onPress={openPrivacyPolicy}
      accessory="disclosure"
    />
    <Cell 
      title="第三方开源许可"
      onPress={openLicenses}
      accessory="disclosure"
    />
  </Section>
  
  <Section>
    <Cell 
      title="检查更新"
      value={updateStatus}
      onPress={checkUpdate}
    />
    <Cell 
      title="反馈问题"
      onPress={openFeedback}
      accessory="disclosure"
    />
    <Cell 
      title="联系我们"
      value="support@hikingapp.com"
      onPress={openEmail}
    />
  </Section>
  
  <Footer>
    <Text>© 2024 徒步伴侣团队 版权所有</Text>
    <Links>
      <Link onPress={openWebsite}>官网</Link>
      <Text> · </Text>
      <Link onPress={openWeibo}>微博</Link>
      <Text> · </Text>
      <Link onPress={openWechat}>公众号</Link>
    </Links>
  </Footer>
</AboutUsPage>
```

---

## 六、关键交互流程图

### 6.1 徒步计时状态流转
```
[IDLE: 00:00:00] 
    ↓ 点击开始
[RUNNING: 计时中] ←→ [PAUSED: 暂停中]
    ↓ 点击结束          ↓ 点击继续
[SAVING: 保存中] ───→ [RUNNING]
    ↓
[ENDED: 已结束] → 跳转历史记录
```

### 6.2 SOS求救流程
```
[地图页长按SOS]
    ↓ 800ms长按动画
[触发求救]
    ↓
[创建SOS记录] → 查询周围3个最近用户
    ↓
[推送通知给接收者] + [跳转求救详情页]
    ↓
[填写详细信息] → 更新推送
    ↓
[等待救援] ←→ [取消求救（安全后）]
```

### 6.3 消息Tab逻辑
```
消息中心
├── 好友消息（永久）
│   └── 单聊列表 → 聊天页（可发送）
├── 临时会话（仅当前徒步）
│   ├── 直接消息 → 单聊页（可发送，显示临时标签）
│   └── 我的提问聚合 → 分支列表 → 单聊页（可发送）
├── 我发布的路况（历史）
│   └── 路况列表 → 详情页（只读，可撤销）
└── 我发布的提问（历史）
    └── 提问列表 → 分支列表 → 单聊页（可发送，若徒步未结束）
```

---

## 七、数据结构补充

### 7.1 徒步记录完整结构
```typescript
interface HikingRecord {
  id: string;
  userId: string;
  
  // 时间信息
  startTime: number;
  endTime: number;
  duration: number; // 实际运动时长（扣除暂停）
  totalPauseTime: number; // 总暂停时长
  
  // 路线数据
  coordinates: Array<{
    lat: number;
    lng: number;
    altitude?: number;
    timestamp: number;
    accuracy?: number;
  }>;
  compressedRoute: string; // 压缩后的路线字符串
  
  // 统计信息
  distance: number; // 米
  maxAltitude: number;
  minAltitude: number;
  avgSpeed: number;
  maxSpeed: number;
  
  // 位置信息
  startLocation: string; // 地名
  endLocation: string;
  country: string;
  province: string;
  city: string;
  
  // 关联数据
  messageCount: number;
  participants: Array<{
    userId: string;
    nickname: string;
    avatar: string;
    messageCount: number;
    snapStatus: 'NONE' | 'PENDING' | 'MUTUAL';
  }>;
  
  // 媒体
  snapshot: string; // 地图截图URL
  photos: string[]; // 用户拍摄的照片
  
  createdAt: number;
  updatedAt: number;
}
```

---

