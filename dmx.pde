import processing.serial.*;
import processing.video.*;

Serial myPort;
Movie movie;

// ============================================
// 레이아웃 상수
// ============================================
final int TAB_CONTENT_X = 50;
final int TAB_CONTENT_OFFSET_Y = 60;
final int DMX_MONITOR_Y = 480;
final int DMX_MONITOR_HEIGHT = 140;
final int TIMELINE_Y = 630;

// Manual CMD Input 위치
final int MANUAL_INPUT_X = 1000;
final int MANUAL_INPUT_Y_OFFSET = 15;  // DMX_MONITOR_Y 기준
final int MANUAL_INPUT_W = 350;
final int MANUAL_INPUT_H = 30;

// Reset Button 위치
final int RESET_BTN_X = 1000;
final int RESET_BTN_Y_OFFSET = 55;  // DMX_MONITOR_Y 기준
final int RESET_BTN_W = 120;
final int RESET_BTN_H = 30;

// ============================================
// DMX 채널 데이터 (18채널)
// ============================================
int[] dmxChannels = new int[18];

// ============================================
// UI 탭 시스템
// ============================================
String[] tabs = {"Position", "Light", "Gobo", "Beam", "Effects"};
int currentTab = 0;

// ============================================
// Position 탭 변수 (CH1-5)
// ============================================
float panValue = 127;     // CH1: Pan (0-255)
float tiltValue = 127;    // CH3: Tilt (0-255)
boolean fineMode = false; // Fine 모드 활성화
int xySpeed = 128;        // CH5: XY Speed

// ============================================
// Light 탭 변수 (CH6-9)
// ============================================
int dimmer = 0;           // CH6: Dimmer
int strobeMode = 0;       // CH7: Strobe (0=off, 1=on, 2=strobe)
int strobeSpeed = 128;    // CH7 strobe speed
int colorMode = 0;        // CH8: Color (0=white, 1-7=colors, 8=CW, 9=CCW)
int colorValue = 0;       // CH8 value
int colorEffect = 0;      // CH9: Color effect

// ============================================
// Gobo 탭 변수 (CH10-12)
// ============================================
int staticGobo = 0;       // CH10: Static gobo
int rotationGobo = 0;     // CH11: Rotation gobo
int goboRotation = 0;     // CH12: Gobo rotation

// ============================================
// Beam 탭 변수 (CH13-16)
// ============================================
int focus = 128;          // CH13: Focus
int zoom = 128;           // CH14: Zoom
boolean prismOn = false;  // CH15: Prism
int prismRotation = 0;    // CH16: Prism rotation

// ============================================
// Effects 탭 변수 (CH17-18)
// ============================================
boolean frostOn = false;  // CH17: Frost
int autoProgram = 0;      // CH18: Auto program

// ============================================
// 타임라인/시퀀서 변수 (Phase 3 - Video Sequencer)
// ============================================
boolean isRecording = false;
boolean isPlaying = false;
ArrayList<Keyframe> timeline = new ArrayList<Keyframe>();
String videoPath = "video.mp4";  // data/ 폴더 기준
float videoTime = 0;  // 현재 비디오 시간 (초)
int selectedKeyframe = -1;  // 선택된 키프레임 인덱스 (-1 = 없음)

// ============================================
// DMX 출력 모니터 변수
// ============================================
ArrayList<DMXCommand> commandHistory = new ArrayList<DMXCommand>();
int maxHistorySize = 7;

// ============================================
// 숫자 직접 입력 모드 변수
// ============================================
boolean isInputMode = false;
int inputChannel = 0;        // 입력 중인 채널 (1-18)
String inputValue = "";      // 입력 중인 값 문자열
int inputMinValue = 0;       // 입력 가능 최소값
int inputMaxValue = 255;     // 입력 가능 최대값

// 채널명 매핑 (CH1-18)
String[] channelNames = {
  "Pan",              // CH1
  "Pan Fine",         // CH2
  "Tilt",             // CH3
  "Tilt Fine",        // CH4
  "XY Speed",         // CH5
  "Dimmer",           // CH6
  "Strobe",           // CH7
  "Color",            // CH8
  "Color Effect",     // CH9
  "Static Gobo",      // CH10
  "Rotation Gobo",    // CH11
  "Gobo Rotation",    // CH12
  "Focus",            // CH13
  "Zoom",             // CH14
  "Prism",            // CH15
  "Prism Rotation",   // CH16
  "Frost",            // CH17
  "Auto Program"      // CH18
};

// ============================================
// 수동 CMD 입력 모드 변수
// ============================================
boolean isManualMode = false;
String manualInput = "";

// ============================================
// 채널 기본값 (초기화 시 사용)
// ============================================
int[] defaultChannelValues = {
  127,  // CH1: Pan
  0,    // CH2: Pan Fine
  127,  // CH3: Tilt
  0,    // CH4: Tilt Fine
  128,  // CH5: XY Speed
  0,    // CH6: Dimmer
  0,    // CH7: Strobe
  0,    // CH8: Color
  0,    // CH9: Color Effect
  0,    // CH10: Static Gobo
  0,    // CH11: Rotation Gobo
  0,    // CH12: Gobo Rotation
  128,  // CH13: Focus
  128,  // CH14: Zoom
  0,    // CH15: Prism
  0,    // CH16: Prism Rotation
  0,    // CH17: Frost
  0     // CH18: Auto Program
};

void setup() {
  size(1400, 700);  // Processing size()는 리터럴 값만 허용

  // 시리얼 포트 연결
  println("사용 가능한 시리얼 포트:");
  printArray(Serial.list());

  try {
    myPort = new Serial(this, "/dev/tty.usbmodem1101", 115200);
    println("✓ 시리얼 포트 연결 성공: /dev/tty.usbmodem1201");
  } catch (Exception e) {
    println("✗ 에러: 시리얼 포트를 열 수 없습니다");
    println("  포트: /dev/tty.usbmodem1201");
    println("  원인: " + e.getMessage());
    println("  → DMX 장치가 연결되어 있는지 확인하세요");
    println("  → 프로그램은 계속 실행되지만 DMX 명령은 전송되지 않습니다");
    myPort = null;
  }

  // 초기화
  for (int i = 0; i < 18; i++) {
    dmxChannels[i] = 0;
  }

  // 비디오 로드
  loadVideo();

  // 시퀀스 자동 로드
  loadSequence("sequence.json");
}

void draw() {
  background(25);

  // 타임라인 동기화 (비디오 재생 중일 때)
  if (isPlaying && movie != null) {
    updateDMXFromTimeline();
  }

  // 타이틀
  fill(255);
  textSize(20);
  text("DMX 18-Channel Moving Head Controller", 20, 30);

  // 탭 메뉴 그리기
  drawTabs();

  // 현재 선택된 탭의 UI 그리기
  drawCurrentTab();

  // DMX 출력 모니터
  drawDMXMonitor();

  // 하단 타임라인 영역 (Phase 3 - Video Sequencer)
  drawTimelineArea();

  // 숫자 입력 모드 UI (최상위 오버레이)
  if (isInputMode) {
    drawInputOverlay();
  }
}

// ============================================
// 탭 메뉴 그리기
// ============================================
void drawTabs() {
  int tabWidth = 150;
  int tabHeight = 40;
  int tabY = 50;

  for (int i = 0; i < tabs.length; i++) {
    int tabX = 20 + i * (tabWidth + 10);

    // 현재 선택된 탭 하이라이트
    if (i == currentTab) {
      fill(80, 120, 200);
      stroke(100, 150, 255);
    } else {
      fill(60);
      stroke(100);
    }

    rect(tabX, tabY, tabWidth, tabHeight, 5);

    // 탭 텍스트
    fill(255);
    textSize(16);
    textAlign(CENTER, CENTER);
    text(tabs[i], tabX + tabWidth/2, tabY + tabHeight/2);
    textAlign(LEFT, BASELINE);
  }
}

// ============================================
// 현재 탭 UI 그리기
// ============================================
void drawCurrentTab() {
  int contentY = 110;

  switch(currentTab) {
    case 0: // Position
      drawPositionTab(contentY);
      break;
    case 1: // Light
      drawLightTab(contentY);
      break;
    case 2: // Gobo
      drawGoboTab(contentY);
      break;
    case 3: // Beam
      drawBeamTab(contentY);
      break;
    case 4: // Effects
      drawEffectsTab(contentY);
      break;
  }
}

// ============================================
// Position 탭 (CH1-5)
// ============================================
void drawPositionTab(int yPos) {
  fill(255);
  textSize(18);
  text("Position Control (Pan/Tilt)", 30, yPos + 20);

  int margin = 30;
  int padX = 50;
  int padY = yPos + TAB_CONTENT_OFFSET_Y;
  int padSize = 300;

  // 2D XY 패드 영역
  fill(40);
  stroke(100);
  strokeWeight(2);
  rect(padX, padY, padSize, padSize);

  // 십자선
  stroke(80);
  strokeWeight(1);
  line(padX + padSize/2, padY, padX + padSize/2, padY + padSize);
  line(padX, padY + padSize/2, padX + padSize, padY + padSize/2);

  // 현재 Pan/Tilt 위치 표시
  float panX = map(panValue, 0, 255, padX, padX + padSize);
  float tiltY = map(tiltValue, 0, 255, padY + padSize, padY);

  fill(255, 100, 100);
  noStroke();
  ellipse(panX, tiltY, 20, 20);

  // 값 표시 영역 (패드 아래 20px 마진) - 한 줄로 표시
  int valueY = padY + padSize + 20;
  fill(255);
  textSize(14);

  // Pan 값
  text("Pan:", padX, valueY + 15);
  drawValueBox(padX + 50, valueY, int(panValue), null);
  text("(" + nf(map(panValue, 0, 255, 0, 540), 0, 1) + "°)", padX + 110, valueY + 15);

  // Tilt 값 (같은 줄)
  text("Tilt:", padX + 200, valueY + 15);
  drawValueBox(padX + 250, valueY, int(tiltValue), null);
  text("(" + nf(map(tiltValue, 0, 255, 0, 270), 0, 1) + "°)", padX + 310, valueY + 15);

  // 오른쪽 컨트롤 영역
  int rightX = padX + padSize + 60;
  int rightY = padY;

  // Fine 모드 토글
  drawCheckbox(rightX, rightY, "Fine Mode", fineMode);

  // XY Speed (Fine Mode 아래 40px 마진)
  int speedY = rightY + 50;
  drawSlider(rightX, speedY, 250, "XY Speed", xySpeed, 0, 255);
  drawValueBox(rightX + 260, speedY, xySpeed, null);

  // Fine 채널 정보 (Speed 아래 60px 마진)
  if (fineMode) {
    int fineY = speedY + 80;
    fill(150, 200, 255);
    textSize(12);
    text("Pan Fine (CH2): " + dmxChannels[1], rightX, fineY);
    text("Tilt Fine (CH4): " + dmxChannels[3], rightX, fineY + 20);
  }
}

// ============================================
// Light 탭 (CH6-9)
// ============================================
void drawLightTab(int yPos) {
  fill(255);
  textSize(18);
  text("Light Control (Dimmer/Strobe/Color)", 30, yPos + 20);

  int margin = 30;
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;

  // Dimmer 섹션
  fill(255);
  textSize(14);
  text("Dimmer", startX, startY - 10);
  drawVerticalSlider(startX, startY, 60, 240, "", dimmer, 0, 255);
  drawValueBox(startX + 70, startY + 105, dimmer, null);

  // Strobe 섹션 (Dimmer 오른쪽 + 마진)
  int strobeX = startX + 160;
  drawStrobeControl(strobeX, startY);

  // Color Wheel 섹션 (Strobe 오른쪽 + 마진)
  int colorX = strobeX + 250;
  drawColorWheel(colorX, startY);

  // Color Effect 섹션 (Color Wheel 아래)
  int effectY = startY + 140;
  drawSlider(colorX, effectY, 220, "Color Effect", colorEffect, 0, 255);
  drawValueBox(colorX + 230, effectY, colorEffect, null);
}

// ============================================
// Gobo 탭 (CH10-12)
// ============================================
void drawGoboTab(int yPos) {
  fill(255);
  textSize(18);
  text("Gobo Control (Pattern Selection)", 30, yPos + 20);

  int margin = 30;
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;

  // Static Gobo 섹션
  fill(255);
  textSize(14);
  text("Static Gobo (CH10)", startX, startY);
  for (int i = 0; i < 8; i++) {
    int btnX = startX + (i % 4) * 75;
    int btnY = startY + 20 + (i / 4) * 75;
    drawGoboButton(btnX, btnY, 65, i + 1, staticGobo == i + 1);
  }

  // Rotation Gobo 섹션 (Static Gobo 오른쪽 + 마진)
  int rotX = startX + 360;
  fill(255);
  textSize(14);
  text("Rotation Gobo (CH11)", rotX, startY);
  for (int i = 0; i < 7; i++) {
    int btnX = rotX + (i % 4) * 75;
    int btnY = startY + 20 + (i / 4) * 75;
    drawGoboButton(btnX, btnY, 65, i + 1, rotationGobo == i + 1);
  }

  // Gobo Rotation 슬라이더 (버튼들 아래 + 마진)
  int rotSliderY = startY + 200;
  drawSlider(startX, rotSliderY, 350, "Gobo Rotation (CH12)", goboRotation, 0, 255);
  drawValueBox(startX + 360, rotSliderY, goboRotation, null);
}

// ============================================
// Beam 탭 (CH13-16)
// ============================================
void drawBeamTab(int yPos) {
  fill(255);
  textSize(18);
  text("Beam Control (Focus/Zoom/Prism)", 30, yPos + 20);

  int margin = 30;
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;

  // Focus 슬라이더
  drawSlider(startX, startY, 350, "Focus (Hazy ← → Clear)", focus, 0, 255);
  drawValueBox(startX + 360, startY, focus, null);

  // Zoom 슬라이더 (Focus 아래 + 마진)
  int zoomY = startY + 70;
  drawSlider(startX, zoomY, 350, "Zoom (Narrow ← → Wide)", zoom, 0, 255);
  drawValueBox(startX + 360, zoomY, zoom, null);

  // Prism 섹션 (Zoom 아래 + 마진)
  int prismY = zoomY + 70;
  drawCheckbox(startX, prismY, "Prism On/Off", prismOn);

  // Prism Rotation (Prism 체크박스 아래)
  if (prismOn) {
    int rotY = prismY + 40;
    drawSlider(startX, rotY, 350, "Prism Rotation", prismRotation, 0, 255);
    drawValueBox(startX + 360, rotY, prismRotation, null);
  }
}

// ============================================
// Effects 탭 (CH17-18)
// ============================================
void drawEffectsTab(int yPos) {
  fill(255);
  textSize(18);
  text("Special Effects (Frost/Auto)", 30, yPos + 20);

  int margin = 30;
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;

  // Frost 토글
  drawCheckbox(startX, startY, "Frost Effect", frostOn);

  // Auto Program (Frost 아래 + 마진)
  int autoY = startY + 50;
  drawSlider(startX, autoY, 350, "Auto Program", autoProgram, 0, 131);
  drawValueBox(startX + 360, autoY, autoProgram, null);
}

// ============================================
// DMX 출력 모니터
// ============================================
void drawDMXMonitor() {
  int monitorY = DMX_MONITOR_Y;
  int monitorHeight = DMX_MONITOR_HEIGHT;

  // 배경
  fill(30);
  stroke(100);
  strokeWeight(1);
  rect(20, monitorY, 1360, monitorHeight);

  // 타이틀
  fill(100, 200, 255);
  textSize(14);
  text("📡 DMX Output Monitor (Recent " + commandHistory.size() + "/" + maxHistorySize + " Commands)", 30, monitorY + 20);

  // 명령 히스토리 표시 (최신 것이 아래)
  fill(200, 255, 200);
  textSize(11);
  int startY = monitorY + 40;
  int lineHeight = 15;

  // 최근 10개만 표시 (아래에서 위로)
  int displayCount = min(commandHistory.size(), maxHistorySize);
  for (int i = 0; i < displayCount; i++) {
    int idx = commandHistory.size() - displayCount + i;
    if (idx >= 0 && idx < commandHistory.size()) {
      DMXCommand cmd = commandHistory.get(idx);
      int yPos = startY + i * lineHeight;

      // 타임스탬프
      fill(150);
      text(cmd.getTimestamp(), 30, yPos);

      // 채널명 (색상 구분)
      fill(255, 200, 100);
      text(cmd.getChannelName(), 110, yPos);

      // 채널 번호
      fill(150);
      text("(CH" + cmd.channel + ")", 240, yPos);

      // 값
      fill(100, 255, 100);
      text("= " + cmd.value, 300, yPos);

      // 구분선
      fill(100);
      text("|", 350, yPos);

      // Raw 명령어
      fill(100, 200, 200);
      text("Raw: " + cmd.getRawCommand(), 370, yPos);
    }
  }

  // 수동 CMD 입력 영역 (모니터 오른쪽 하단)
  drawManualInput();

  // RESET ALL 버튼
  drawResetButton();
}

// ============================================
// 수동 CMD 입력
// ============================================
void drawManualInput() {
  int inputX = MANUAL_INPUT_X;
  int inputY = DMX_MONITOR_Y + MANUAL_INPUT_Y_OFFSET;
  int inputW = MANUAL_INPUT_W;
  int inputH = MANUAL_INPUT_H;

  // 레이블
  fill(100, 200, 255);
  textSize(11);
  text("⌨️ Manual CMD:", inputX, inputY - 8);

  // 입력 박스 배경
  if (isManualMode) {
    fill(50, 70, 50);  // 활성화 시 약간 밝게
    stroke(100, 255, 100);
    strokeWeight(2);
  } else {
    fill(35);
    stroke(80);
    strokeWeight(1);
  }
  rect(inputX, inputY, inputW, inputH, 3);

  // 입력 텍스트 표시
  fill(200, 255, 200);
  textSize(12);
  textAlign(LEFT, CENTER);
  String displayText = isManualMode ? manualInput + "_" : "CH5=200";
  text(displayText, inputX + 8, inputY + inputH/2);
  textAlign(LEFT, BASELINE);

  // 플레이스홀더 힌트
  if (!isManualMode && manualInput.length() == 0) {
    fill(100);
    textSize(10);
    textAlign(LEFT, CENTER);
    text("(Click to type)", inputX + 80, inputY + inputH/2);
    textAlign(LEFT, BASELINE);
  }
}

// ============================================
// RESET ALL 버튼
// ============================================
void drawResetButton() {
  int btnX = RESET_BTN_X;
  int btnY = DMX_MONITOR_Y + RESET_BTN_Y_OFFSET;
  int btnW = RESET_BTN_W;
  int btnH = RESET_BTN_H;

  // 버튼 배경 (호버 효과)
  boolean isHover = mouseX > btnX && mouseX < btnX + btnW &&
                    mouseY > btnY && mouseY < btnY + btnH;

  if (isHover) {
    fill(80, 40, 40);  // 호버 시 약간 밝은 빨강
    stroke(255, 100, 100);
    strokeWeight(2);
  } else {
    fill(60, 30, 30);
    stroke(150, 80, 80);
    strokeWeight(1);
  }
  rect(btnX, btnY, btnW, btnH, 3);

  // 버튼 텍스트
  fill(255, 150, 150);
  textSize(11);
  textAlign(CENTER, CENTER);
  text("🔄 RESET ALL", btnX + btnW/2, btnY + btnH/2);
  textAlign(LEFT, BASELINE);
}

// ============================================
// 타임라인 영역 (Phase 3에서 구현)
// ============================================
void drawTimelineArea() {
  int tlY = TIMELINE_Y;
  int tlH = 120;  // 높이 확장 (60 → 120)

  // 배경
  fill(50);
  stroke(100);
  rect(20, tlY, 1360, tlH);

  // 비디오 없으면 경고 메시지
  if (movie == null) {
    fill(255, 150, 150);
    textSize(12);
    text("⚠️ 비디오 파일 없음 - data/video.mp4 파일을 추가하세요", 30, tlY + 30);
    return;
  }

  // 비디오 프리뷰 (80x60)
  int previewX = 30;
  int previewY = tlY + 5;
  int previewW = 80;
  int previewH = 50;

  if (movie.width > 0 && movie.height > 0) {
    image(movie, previewX, previewY, previewW, previewH);
  } else {
    fill(30);
    rect(previewX, previewY, previewW, previewH);
    fill(100);
    textSize(10);
    textAlign(CENTER, CENTER);
    text("No\nFrame", previewX + previewW/2, previewY + previewH/2);
    textAlign(LEFT, BASELINE);
  }

  // 재생 컨트롤 버튼
  drawPlaybackControls(previewX + previewW + 20, tlY + 10);

  // 타임라인 시크바
  drawTimelineSeekbar(300, tlY + 15, 980);

  // 단축키 힌트
  fill(150);
  textSize(10);
  text("[K]Add  [Del]Delete  [Space]Play/Pause  (Auto-saved)", 1050, tlY + 55);

  // 키프레임 정보 및 컨트롤
  fill(200);
  textSize(11);
  text("Keyframes: " + timeline.size(), 1290, tlY + 20);

  // 키프레임 컨트롤 버튼
  drawKeyframeControls(1290, tlY + 35);

  // 선택된 키프레임 정보 표시
  drawSelectedKeyframeInfo(tlY);
}

// 선택된 키프레임 정보 표시
void drawSelectedKeyframeInfo(int tlY) {
  if (selectedKeyframe < 0 || selectedKeyframe >= timeline.size()) {
    return;  // 선택된 키프레임 없음
  }

  Keyframe kf = timeline.get(selectedKeyframe);
  int infoY = tlY + 70;  // 타임라인 아래쪽 시작

  // 헤더
  fill(255, 200, 100);
  textSize(12);
  textAlign(LEFT, TOP);
  text("⚡ Selected Keyframe #" + (selectedKeyframe + 1) + " @ " + formatTime(kf.timestamp), 30, infoY);

  // 채널 값 표시 (3줄로 나눠서)
  fill(200, 220, 255);
  textSize(10);
  int startX = 30;
  int lineHeight = 14;

  // 1줄: CH1~6
  String line1 = "";
  for (int i = 0; i < 6; i++) {
    line1 += "CH" + (i + 1) + ":" + kf.dmxValues[i] + "  ";
  }
  text(line1, startX, infoY + 18);

  // 2줄: CH7~12
  String line2 = "";
  for (int i = 6; i < 12; i++) {
    line2 += "CH" + (i + 1) + ":" + kf.dmxValues[i] + "  ";
  }
  text(line2, startX, infoY + 18 + lineHeight);

  // 3줄: CH13~18
  String line3 = "";
  for (int i = 12; i < 18; i++) {
    line3 += "CH" + (i + 1) + ":" + kf.dmxValues[i] + "  ";
  }
  text(line3, startX, infoY + 18 + lineHeight * 2);

  textAlign(LEFT, BASELINE);
}

// 키프레임 추가/삭제 버튼
void drawKeyframeControls(int x, int y) {
  int btnW = 35;
  int btnH = 20;

  // Add Keyframe 버튼
  boolean addHover = mouseX > x && mouseX < x + btnW && mouseY > y && mouseY < y + btnH;
  if (addHover) {
    fill(80, 120, 80);
    stroke(150, 255, 150);
  } else {
    fill(60, 100, 60);
    stroke(100, 200, 100);
  }
  strokeWeight(1);
  rect(x, y, btnW, btnH, 2);
  fill(200, 255, 200);
  textSize(10);
  textAlign(CENTER, CENTER);
  text("+ K", x + btnW/2, y + btnH/2);
  textAlign(LEFT, BASELINE);

  // Delete Keyframe 버튼
  int delX = x + btnW + 5;
  boolean delHover = mouseX > delX && mouseX < delX + btnW && mouseY > y && mouseY < y + btnH;
  boolean hasSelection = selectedKeyframe >= 0 && selectedKeyframe < timeline.size();

  if (!hasSelection) {
    fill(40);
    stroke(60);
  } else if (delHover) {
    fill(120, 60, 60);
    stroke(255, 150, 150);
  } else {
    fill(100, 40, 40);
    stroke(200, 100, 100);
  }
  strokeWeight(1);
  rect(delX, y, btnW, btnH, 2);

  if (hasSelection) {
    fill(255, 200, 200);
  } else {
    fill(100);
  }
  textSize(10);
  textAlign(CENTER, CENTER);
  text("🗑 " + (selectedKeyframe + 1), delX + btnW/2, y + btnH/2);
  textAlign(LEFT, BASELINE);
}

// ============================================
// 숫자 입력 오버레이
// ============================================
void drawInputOverlay() {
  // 반투명 배경
  fill(0, 0, 0, 180);
  rect(0, 0, width, height);

  // 입력창
  int boxW = 300;
  int boxH = 150;
  int boxX = (width - boxW) / 2;
  int boxY = (height - boxH) / 2;

  // 입력창 배경
  fill(40);
  stroke(100, 150, 255);
  strokeWeight(2);
  rect(boxX, boxY, boxW, boxH, 10);

  // 타이틀
  fill(100, 200, 255);
  textSize(16);
  textAlign(CENTER, TOP);
  text("Direct Value Input", boxX + boxW/2, boxY + 15);

  // 채널 정보
  fill(255, 200, 100);
  textSize(14);
  text(channelNames[inputChannel - 1] + " (CH" + inputChannel + ")", boxX + boxW/2, boxY + 40);

  // 입력 필드
  fill(60);
  stroke(150);
  strokeWeight(1);
  rect(boxX + 30, boxY + 65, boxW - 60, 35, 5);

  // 입력된 값 표시
  fill(100, 255, 100);
  textSize(20);
  String displayValue = inputValue.length() > 0 ? inputValue : "0";
  text(displayValue + "█", boxX + boxW/2, boxY + 75);

  // 안내 메시지
  fill(200);
  textSize(12);
  text("Range: " + inputMinValue + " - " + inputMaxValue, boxX + boxW/2, boxY + 110);
  text("[Enter] = OK  |  [Esc] = Cancel", boxX + boxW/2, boxY + 130);

  textAlign(LEFT, BASELINE);
  strokeWeight(1);
}

// ============================================
// UI 위젯 헬퍼 함수들
// ============================================

// 체크박스
void drawCheckbox(int x, int y, String label, boolean checked) {
  // 체크박스
  fill(checked ? color(100, 200, 100) : 50);
  stroke(100);
  rect(x, y, 20, 20);

  if (checked) {
    fill(255);
    textSize(16);
    text("✓", x + 4, y + 16);
  }

  // 레이블
  fill(255);
  textSize(14);
  text(label, x + 30, y + 15);
}

// 클릭 가능한 값 박스 (입력 모드 활성화용)
void drawValueBox(int x, int y, int value, String label) {
  // 박스 배경
  fill(70);
  stroke(120);
  strokeWeight(1);
  rect(x, y, 50, 25, 3);

  // 값 표시
  fill(200, 255, 200);
  textSize(14);
  textAlign(CENTER, CENTER);
  text(str(value), x + 25, y + 12);
  textAlign(LEFT, BASELINE);

  // 레이블 (선택사항)
  if (label != null && label.length() > 0) {
    fill(150);
    textSize(10);
    text(label, x, y - 12);
  }
}

// 가로 슬라이더
void drawSlider(int x, int y, int w, String label, int value, int minVal, int maxVal) {
  // 레이블
  fill(255);
  textSize(14);
  text(label + ": " + value, x, y);

  // 슬라이더 바 (높이 30px로 확대)
  fill(60);
  stroke(100);
  strokeWeight(1);
  rect(x, y + 10, w, 30, 3);

  // 핸들 (더 크고 눈에 띄게)
  float handleX = map(value, minVal, maxVal, x, x + w);
  fill(100, 150, 255);
  stroke(150, 200, 255);
  strokeWeight(2);
  rect(handleX - 8, y + 5, 16, 40, 5);
  noStroke();
}

// 세로 슬라이더
void drawVerticalSlider(int x, int y, int w, int h, String label, int value, int minVal, int maxVal) {
  // 레이블
  fill(255);
  textSize(14);
  text(label, x, y - 10);

  // 슬라이더 바 (둥근 모서리)
  fill(60);
  stroke(100);
  strokeWeight(1);
  rect(x, y, w, h, 3);

  // 핸들 (더 크고 눈에 띄게)
  float handleY = map(value, minVal, maxVal, y + h, y);
  fill(100, 150, 255);
  stroke(150, 200, 255);
  strokeWeight(2);
  rect(x - 5, handleY - 8, w + 10, 16, 5);
  noStroke();

  // 값 표시
  fill(255);
  textSize(12);
  text(value, x + 5, y + h + 20);
}

// Strobe 컨트롤
void drawStrobeControl(int x, int y) {
  fill(255);
  textSize(14);
  text("Strobe", x, y);

  // Off / On / Strobe 버튼
  String[] modes = {"Off", "On", "Strobe"};
  for (int i = 0; i < 3; i++) {
    int btnY = y + 10 + i * 40;
    fill(strobeMode == i ? color(200, 100, 100) : 60);
    stroke(100);
    rect(x, btnY, 80, 30);

    fill(255);
    textAlign(CENTER, CENTER);
    text(modes[i], x + 40, btnY + 15);
    textAlign(LEFT, BASELINE);
  }

  // Strobe Speed
  if (strobeMode == 2) {
    drawSlider(x, y + 140, 150, "Speed", strobeSpeed, 8, 250);
    drawValueBox(x + 160, y + 140, strobeSpeed, null);
  }
}

// Color Wheel
void drawColorWheel(int x, int y) {
  fill(255);
  textSize(14);
  text("Color Wheel", x, y);

  String[] colors = {"White", "C1", "C2", "C3", "C4", "C5", "C6", "C7"};
  color[] colorValues = {
    color(255, 255, 255),
    color(255, 0, 0),
    color(0, 255, 0),
    color(0, 0, 255),
    color(255, 255, 0),
    color(255, 0, 255),
    color(0, 255, 255),
    color(255, 128, 0)
  };

  for (int i = 0; i < 8; i++) {
    int btnX = x + (i % 4) * 55;
    int btnY = y + 20 + (i / 4) * 55;

    fill(colorValues[i]);
    stroke(colorMode == i ? color(255, 255, 0) : color(100));
    strokeWeight(colorMode == i ? 3 : 1);
    ellipse(btnX + 20, btnY + 20, 40, 40);

    fill(0);
    textSize(10);
    textAlign(CENTER, CENTER);
    text(colors[i], btnX + 20, btnY + 20);
    textAlign(LEFT, BASELINE);
  }
  strokeWeight(1);
}

// Gobo 버튼
void drawGoboButton(int x, int y, int size, int num, boolean selected) {
  fill(selected ? color(255, 200, 100) : 80);
  stroke(selected ? color(255, 150, 0) : 100);
  strokeWeight(selected ? 2 : 1);
  rect(x, y, size, size);

  fill(255);
  textSize(12);
  textAlign(CENTER, CENTER);
  text("G" + num, x + size/2, y + size/2);
  textAlign(LEFT, BASELINE);
  strokeWeight(1);
}

// ============================================
// 마우스 클릭 이벤트
// ============================================
void mousePressed() {
  // 타임라인 컨트롤 버튼 클릭 감지 (최우선)
  if (handleTimelineClick()) {
    return;
  }

  // 수동 CMD 입력 박스 클릭 감지 (우선 체크)
  int inputX = MANUAL_INPUT_X;
  int inputY = DMX_MONITOR_Y + MANUAL_INPUT_Y_OFFSET;
  int inputW = MANUAL_INPUT_W;
  int inputH = MANUAL_INPUT_H;
  if (mouseX > inputX && mouseX < inputX + inputW &&
      mouseY > inputY && mouseY < inputY + inputH) {
    isManualMode = true;
    manualInput = "";
    return;
  }

  // RESET ALL 버튼 클릭 감지
  int btnX = RESET_BTN_X;
  int btnY = DMX_MONITOR_Y + RESET_BTN_Y_OFFSET;
  int btnW = RESET_BTN_W;
  int btnH = RESET_BTN_H;
  if (mouseX > btnX && mouseX < btnX + btnW &&
      mouseY > btnY && mouseY < btnY + btnH) {
    resetAllChannels();
    return;
  }

  // 입력 모드일 때는 다른 클릭 무시
  if (isInputMode || isManualMode) {
    return;
  }

  // 탭 클릭 감지
  int tabWidth = 150;
  int tabHeight = 40;
  int tabY = 50;

  for (int i = 0; i < tabs.length; i++) {
    int tabX = 20 + i * (tabWidth + 10);
    if (mouseX > tabX && mouseX < tabX + tabWidth &&
        mouseY > tabY && mouseY < tabY + tabHeight) {
      currentTab = i;
      return;
    }
  }

  // 값 박스 클릭으로 입력 모드 활성화 체크
  if (checkValueBoxClick()) {
    return;  // 입력 모드 활성화됨
  }

  // 탭별 클릭 처리
  handleTabClicks();
}

void mouseDragged() {
  // 입력 모드일 때는 드래그 무시
  if (isInputMode) {
    return;
  }
  handleTabDrags();
}

// ============================================
// 값 박스 클릭으로 입력 모드 활성화 체크
// ============================================
boolean checkValueBoxClick() {
  int contentY = 110;

  switch(currentTab) {
    case 0: // Position 탭
      return checkPositionValueBox(contentY);
    case 1: // Light 탭
      return checkLightValueBox(contentY);
    case 2: // Gobo 탭
      return checkGoboValueBox(contentY);
    case 3: // Beam 탭
      return checkBeamValueBox(contentY);
    case 4: // Effects 탭
      return checkEffectsValueBox(contentY);
  }
  return false;
}

// Position 탭 값 박스 클릭 체크
boolean checkPositionValueBox(int yPos) {
  int padX = 50;
  int padY = yPos + TAB_CONTENT_OFFSET_Y;
  int padSize = 300;
  int valueY = padY + padSize + 20;

  // Pan 값 박스
  if (isInsideBox(padX + 50, valueY, 50, 25)) {
    activateInputMode(1, 0, 255);
    return true;
  }

  // Tilt 값 박스
  if (isInsideBox(padX + 50, valueY + 30, 50, 25)) {
    activateInputMode(3, 0, 255);
    return true;
  }

  // XY Speed 값 박스
  int rightX = padX + padSize + 60;
  int rightY = padY;
  int speedY = rightY + 50;
  if (isInsideBox(rightX + 260, speedY + 10, 50, 25)) {
    activateInputMode(5, 0, 255);
    return true;
  }

  return false;
}

// Light 탭 값 박스 클릭 체크
boolean checkLightValueBox(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;

  // Dimmer 값 박스
  if (isInsideBox(startX + 70, startY + 105, 50, 25)) {
    activateInputMode(6, 0, 255);
    return true;
  }

  // Strobe Speed 값 박스 (strobeMode == 2일 때만)
  if (strobeMode == 2) {
    int strobeX = startX + 160;
    if (isInsideBox(strobeX + 160, startY + 140, 50, 25)) {
      activateInputMode(7, 8, 250);
      return true;
    }
  }

  // Color Effect 값 박스
  int strobeX = startX + 160;
  int colorX = strobeX + 250;
  int effectY = startY + 140;
  if (isInsideBox(colorX + 230, effectY + 10, 50, 25)) {
    activateInputMode(9, 0, 255);
    return true;
  }

  return false;
}

// Gobo 탭 값 박스 클릭 체크
boolean checkGoboValueBox(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;
  int rotSliderY = startY + 200;

  // Gobo Rotation 값 박스
  if (isInsideBox(startX + 360, rotSliderY + 10, 50, 25)) {
    activateInputMode(12, 0, 255);
    return true;
  }

  return false;
}

// Beam 탭 값 박스 클릭 체크
boolean checkBeamValueBox(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;

  // Focus 값 박스
  if (isInsideBox(startX + 360, startY + 10, 50, 25)) {
    activateInputMode(13, 0, 255);
    return true;
  }

  // Zoom 값 박스
  int zoomY = startY + 70;
  if (isInsideBox(startX + 360, zoomY + 10, 50, 25)) {
    activateInputMode(14, 0, 255);
    return true;
  }

  // Prism Rotation 값 박스 (prismOn일 때만)
  if (prismOn) {
    int prismY = zoomY + 70;
    int rotY = prismY + 40;
    if (isInsideBox(startX + 360, rotY + 10, 50, 25)) {
      activateInputMode(16, 0, 255);
      return true;
    }
  }

  return false;
}

// Effects 탭 값 박스 클릭 체크
boolean checkEffectsValueBox(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;
  int autoY = startY + 50;

  // Auto Program 값 박스
  if (isInsideBox(startX + 360, autoY + 10, 50, 25)) {
    activateInputMode(18, 0, 131);
    return true;
  }

  return false;
}

// 박스 내부 클릭 체크 헬퍼
boolean isInsideBox(int x, int y, int w, int h) {
  return mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h;
}

// 입력 모드 활성화
void activateInputMode(int channel, int minVal, int maxVal) {
  isInputMode = true;
  inputChannel = channel;
  inputValue = "";
  inputMinValue = minVal;
  inputMaxValue = maxVal;
  println("Input mode activated for CH" + channel + " (" + channelNames[channel - 1] + ")");
}

void handleTabClicks() {
  int contentY = 110;

  switch(currentTab) {
    case 0: // Position
      handlePositionClicks(contentY);
      break;
    case 1: // Light
      handleLightClicks(contentY);
      break;
    case 2: // Gobo
      handleGoboClicks(contentY);
      break;
    case 3: // Beam
      handleBeamClicks(contentY);
      break;
    case 4: // Effects
      handleEffectsClicks(contentY);
      break;
  }
}

void handleTabDrags() {
  int contentY = 110;

  switch(currentTab) {
    case 0: // Position
      handlePositionDrags(contentY);
      break;
    case 1: // Light
      handleLightDrags(contentY);
      break;
    case 2: // Gobo
      handleGoboDrags(contentY);
      break;
    case 3: // Beam
      handleBeamDrags(contentY);
      break;
    case 4: // Effects
      handleEffectsDrags(contentY);
      break;
  }
}

// ============================================
// Position 탭 인터랙션
// ============================================
void handlePositionClicks(int yPos) {
  int padX = 50;
  int padY = yPos + TAB_CONTENT_OFFSET_Y;
  int padSize = 300;
  int rightX = padX + padSize + 60;
  int rightY = padY;

  // Fine 모드 체크박스
  if (mouseX > rightX && mouseX < rightX + 20 &&
      mouseY > rightY && mouseY < rightY + 20) {
    fineMode = !fineMode;
    return;
  }

  // XY Speed 슬라이더 클릭 (확대된 영역)
  int speedY = rightY + 50;
  int sliderW = 250;
  if (mouseX > rightX && mouseX < rightX + sliderW &&
      mouseY > speedY && mouseY < speedY + 50) {  // 클릭 영역 확대
    xySpeed = int(constrain(map(mouseX, rightX, rightX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(5, xySpeed);
  }
}

void handlePositionDrags(int yPos) {
  int padX = 50;
  int padY = yPos + TAB_CONTENT_OFFSET_Y;
  int padSize = 300;

  // XY 패드 드래그
  if (mouseX > padX && mouseX < padX + padSize &&
      mouseY > padY && mouseY < padY + padSize) {
    panValue = constrain(map(mouseX, padX, padX + padSize, 0, 255), 0, 255);
    tiltValue = constrain(map(mouseY, padY + padSize, padY, 0, 255), 0, 255);

    updateDMXChannel(1, int(panValue));
    updateDMXChannel(3, int(tiltValue));
  }

  // XY Speed 슬라이더 (확대된 드래그 영역)
  int rightX = padX + padSize + 60;
  int rightY = padY;
  int speedY = rightY + 50;
  int sliderW = 250;
  if (mouseX > rightX && mouseX < rightX + sliderW &&
      mouseY > speedY && mouseY < speedY + 50) {  // 드래그 영역 확대
    xySpeed = int(constrain(map(mouseX, rightX, rightX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(5, xySpeed);
  }
}

// ============================================
// Light 탭 인터랙션
// ============================================
void handleLightClicks(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;
  int strobeX = startX + 160;

  // Strobe 모드 버튼
  for (int i = 0; i < 3; i++) {
    int btnY = startY + 10 + i * 40;
    if (mouseX > strobeX && mouseX < strobeX + 80 &&
        mouseY > btnY && mouseY < btnY + 30) {
      strobeMode = i;
      updateStrobeChannel();
      return;
    }
  }

  // Color Wheel
  int colorX = strobeX + 250;
  for (int i = 0; i < 8; i++) {
    int btnX = colorX + (i % 4) * 55;
    int btnY = startY + 20 + (i / 4) * 55;
    float dist = dist(mouseX, mouseY, btnX + 20, btnY + 20);
    if (dist < 20) {
      colorMode = i;
      updateColorChannel();
      return;
    }
  }

  // Strobe Speed 슬라이더 클릭 (strobeMode == 2일 때) - 클릭 영역 확대
  if (strobeMode == 2) {
    int sliderW = 150;
    if (mouseX > strobeX && mouseX < strobeX + sliderW &&
        mouseY > startY + 140 && mouseY < startY + 180) {  // 클릭 영역 확대
      strobeSpeed = int(constrain(map(mouseX, strobeX, strobeX + sliderW, 8, 250), 8, 250));
      updateStrobeChannel();
      return;
    }
  }

  // Dimmer 슬라이더 클릭 (세로) - 좌우 영역 확대
  if (mouseX > startX - 20 && mouseX < startX + 80 &&  // 좌우 20px 확대
      mouseY > startY && mouseY < startY + 240) {
    dimmer = int(constrain(map(mouseY, startY + 240, startY, 0, 255), 0, 255));
    updateDMXChannel(6, dimmer);
    return;
  }

  // Color Effect 슬라이더 클릭 - 클릭 영역 확대
  int effectY = startY + 140;
  int sliderW = 220;
  if (mouseX > colorX && mouseX < colorX + sliderW &&
      mouseY > effectY && mouseY < effectY + 50) {  // 클릭 영역 확대
    colorEffect = int(constrain(map(mouseX, colorX, colorX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(9, colorEffect);
  }
}

void handleLightDrags(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;

  // Dimmer 슬라이더 (세로) - 좌우 영역 확대
  if (mouseX > startX - 20 && mouseX < startX + 80 &&
      mouseY > startY && mouseY < startY + 240) {
    dimmer = int(constrain(map(mouseY, startY + 240, startY, 0, 255), 0, 255));
    updateDMXChannel(6, dimmer);
  }

  // Strobe Speed 슬라이더 - 클릭 영역 확대
  if (strobeMode == 2) {
    int strobeX = startX + 160;
    int sliderW = 150;
    if (mouseX > strobeX && mouseX < strobeX + sliderW &&
        mouseY > startY + 140 && mouseY < startY + 180) {
      strobeSpeed = int(constrain(map(mouseX, strobeX, strobeX + sliderW, 8, 250), 8, 250));
      updateStrobeChannel();
    }
  }

  // Color Effect 슬라이더 - 클릭 영역 확대
  int strobeX = startX + 160;
  int colorX = strobeX + 250;
  int effectY = startY + 140;
  int sliderW = 220;
  if (mouseX > colorX && mouseX < colorX + sliderW &&
      mouseY > effectY && mouseY < effectY + 50) {
    colorEffect = int(constrain(map(mouseX, colorX, colorX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(9, colorEffect);
  }
}

// ============================================
// Gobo 탭 인터랙션
// ============================================
void handleGoboClicks(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;

  // Static Gobo (토글: 다시 클릭하면 off)
  for (int i = 0; i < 8; i++) {
    int btnX = startX + (i % 4) * 75;
    int btnY = startY + 20 + (i / 4) * 75;
    if (mouseX > btnX && mouseX < btnX + 65 &&
        mouseY > btnY && mouseY < btnY + 65) {

      // 이미 선택된 고보를 다시 클릭하면 off
      if (staticGobo == i + 1) {
        staticGobo = 0;
        updateGoboChannel(10, 0);
      } else {
        staticGobo = i + 1;
        updateGoboChannel(10, i + 1);
      }
      return;
    }
  }

  // Rotation Gobo (토글: 다시 클릭하면 off)
  int rotX = startX + 360;
  for (int i = 0; i < 7; i++) {
    int btnX = rotX + (i % 4) * 75;
    int btnY = startY + 20 + (i / 4) * 75;
    if (mouseX > btnX && mouseX < btnX + 65 &&
        mouseY > btnY && mouseY < btnY + 65) {

      // 이미 선택된 고보를 다시 클릭하면 off
      if (rotationGobo == i + 1) {
        rotationGobo = 0;
        updateGoboChannel(11, 0);
      } else {
        rotationGobo = i + 1;
        updateGoboChannel(11, i + 1);
      }
      return;
    }
  }

  // Gobo Rotation 슬라이더 클릭
  int rotSliderY = startY + 200;
  int sliderW = 350;
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > rotSliderY + 10 && mouseY < rotSliderY + 30) {
    goboRotation = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(12, goboRotation);
  }
}

void handleGoboDrags(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;
  int rotSliderY = startY + 200;
  int sliderW = 350;

  // Gobo Rotation 슬라이더 - 클릭 영역 확대
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > rotSliderY && mouseY < rotSliderY + 50) {
    goboRotation = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(12, goboRotation);
  }
}

// ============================================
// Beam 탭 인터랙션
// ============================================
void handleBeamClicks(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;
  int zoomY = startY + 70;
  int prismY = zoomY + 70;
  int sliderW = 350;

  // Prism 체크박스
  if (mouseX > startX && mouseX < startX + 20 &&
      mouseY > prismY && mouseY < prismY + 20) {
    prismOn = !prismOn;
    updateDMXChannel(15, prismOn ? 128 : 0);
    return;
  }

  // Focus 슬라이더 클릭
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > startY + 10 && mouseY < startY + 30) {
    focus = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(13, focus);
    return;
  }

  // Zoom 슬라이더 클릭
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > zoomY + 10 && mouseY < zoomY + 30) {
    zoom = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(14, zoom);
    return;
  }

  // Prism Rotation 슬라이더 클릭
  if (prismOn) {
    int rotY = prismY + 40;
    if (mouseX > startX && mouseX < startX + sliderW &&
        mouseY > rotY + 10 && mouseY < rotY + 30) {
      prismRotation = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
      updateDMXChannel(16, prismRotation);
    }
  }
}

void handleBeamDrags(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;
  int sliderW = 350;

  // Focus 슬라이더 - 클릭 영역 확대
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > startY && mouseY < startY + 50) {
    focus = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(13, focus);
  }

  // Zoom 슬라이더 - 클릭 영역 확대
  int zoomY = startY + 70;
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > zoomY && mouseY < zoomY + 50) {
    zoom = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(14, zoom);
  }

  // Prism Rotation - 클릭 영역 확대
  if (prismOn) {
    int prismY = zoomY + 70;
    int rotY = prismY + 40;
    if (mouseX > startX && mouseX < startX + sliderW &&
        mouseY > rotY && mouseY < rotY + 50) {
      prismRotation = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
      updateDMXChannel(16, prismRotation);
    }
  }
}

// ============================================
// Effects 탭 인터랙션
// ============================================
void handleEffectsClicks(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;
  int autoY = startY + 50;
  int sliderW = 350;

  // Frost 체크박스
  if (mouseX > startX && mouseX < startX + 20 &&
      mouseY > startY && mouseY < startY + 20) {
    frostOn = !frostOn;
    updateDMXChannel(17, frostOn ? 128 : 0);
    return;
  }

  // Auto Program 슬라이더 클릭
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > autoY + 10 && mouseY < autoY + 30) {
    autoProgram = int(constrain(map(mouseX, startX, startX + sliderW, 0, 131), 0, 131));
    updateDMXChannel(18, autoProgram);
  }
}

void handleEffectsDrags(int yPos) {
  int startX = TAB_CONTENT_X;
  int startY = yPos + TAB_CONTENT_OFFSET_Y;
  int autoY = startY + 50;
  int sliderW = 350;

  // Auto Program 슬라이더 - 클릭 영역 확대
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > autoY && mouseY < autoY + 50) {
    autoProgram = int(constrain(map(mouseX, startX, startX + sliderW, 0, 131), 0, 131));
    updateDMXChannel(18, autoProgram);
  }
}

// ============================================
// DMX 채널 업데이트 헬퍼
// ============================================
void updateDMXChannel(int channel, int value) {
  dmxChannels[channel - 1] = constrain(value, 0, 255);
  sendDMX(channel, dmxChannels[channel - 1]);

  // 키프레임이 선택된 상태면 해당 키프레임 값도 실시간 업데이트
  if (selectedKeyframe >= 0 && selectedKeyframe < timeline.size()) {
    timeline.get(selectedKeyframe).dmxValues[channel - 1] = dmxChannels[channel - 1];
    saveSequence("sequence.json");  // 자동 저장
  }
}

void updateStrobeChannel() {
  int value = 0;
  if (strobeMode == 0) value = 0;        // Off
  else if (strobeMode == 1) value = 255; // On
  else value = strobeSpeed;              // Strobe

  updateDMXChannel(7, value);
}

void updateColorChannel() {
  int value = 0;
  if (colorMode == 0) value = 0;                    // White
  else if (colorMode >= 1 && colorMode <= 7) {      // Color 1-7
    value = 16 + (colorMode - 1) * 16;
  }

  updateDMXChannel(8, value);
}

void updateGoboChannel(int channel, int goboNum) {
  int value = 0;
  if (goboNum == 0) value = 0;
  else value = 16 + (goboNum - 1) * 16;

  updateDMXChannel(channel, value);
}

// ============================================
// 키보드 이벤트 (프리셋 + 숫자 입력)
// ============================================
void keyPressed() {
  // 타임라인 단축키 (최우선)
  if (!isManualMode && !isInputMode) {
    // K 키: 키프레임 추가
    if (key == 'k' || key == 'K') {
      addKeyframe();
      return;
    }

    // Delete/Backspace: 선택된 키프레임 삭제
    if (key == DELETE || key == BACKSPACE) {
      deleteSelectedKeyframe();
      return;
    }

    // 스페이스바: 재생/일시정지 토글
    if (key == ' ') {
      if (isPlaying) {
        pauseVideo();
      } else {
        playVideo();
      }
      return;
    }
  }

  // 수동 CMD 입력 모드일 때
  if (isManualMode) {
    // CODED 키가 아닐 때만 처리
    if (key != CODED) {
      if (key == ENTER || key == RETURN || key == 10) {
        // Enter: CMD 전송
        if (manualInput.length() > 0) {
          sendManualCommand(manualInput);
        }
        isManualMode = false;
        manualInput = "";
      } else if (key == ESC) {
        // ESC: 취소
        isManualMode = false;
        manualInput = "";
        key = 0;  // ESC 기본 동작 방지
      } else if (key == BACKSPACE || key == DELETE || key == 8 || key == 127) {
        // 백스페이스
        if (manualInput.length() > 0) {
          manualInput = manualInput.substring(0, manualInput.length() - 1);
        }
      } else if (key >= 32 && key <= 126) {
        // 출력 가능한 ASCII 문자만 허용 (영문, 숫자, 기호)
        manualInput += key;
      }
    }
    return;
  }

  // 숫자 입력 모드일 때
  if (isInputMode) {
    if (key >= '0' && key <= '9') {
      // 숫자 입력
      inputValue += key;
    } else if (key == BACKSPACE || key == DELETE) {
      // 백스페이스: 마지막 문자 삭제
      if (inputValue.length() > 0) {
        inputValue = inputValue.substring(0, inputValue.length() - 1);
      }
    } else if (key == ENTER || key == RETURN) {
      // Enter: 값 확정
      if (inputValue.length() > 0) {
        int value = int(inputValue);
        value = constrain(value, inputMinValue, inputMaxValue);

        // DMX 채널 업데이트
        updateDMXChannel(inputChannel, value);

        // UI 변수 동기화
        syncUIFromDMX();

        println("Direct input: CH" + inputChannel + " = " + value);
      }
      // 입력 모드 종료
      isInputMode = false;
      inputValue = "";
    } else if (key == ESC) {
      // Escape: 취소
      isInputMode = false;
      inputValue = "";
      key = 0;  // ESC 기본 동작 방지
    }
    return;  // 입력 모드일 때는 다른 키 처리 안 함
  }
}

// ============================================
// DMX → UI 동기화
// ============================================
void syncUIFromDMX() {
  panValue = dmxChannels[0];
  tiltValue = dmxChannels[2];
  xySpeed = dmxChannels[4];
  dimmer = dmxChannels[5];
  strobeSpeed = dmxChannels[6];
  colorEffect = dmxChannels[8];
  goboRotation = dmxChannels[11];
  focus = dmxChannels[12];
  zoom = dmxChannels[13];
  prismRotation = dmxChannels[15];
  autoProgram = dmxChannels[17];
}

// ============================================
// 시리얼 전송
// ============================================
void sendDMX(int channel, int value) {
  String cmd = "CH" + channel + "=" + value + "\n";

  // 시리얼 포트 연결 확인
  if (myPort == null) {
    println("경고: 시리얼 연결 없음 - " + cmd.trim());
    // DMX 출력 모니터에는 추가 (UI 동작 확인용)
    commandHistory.add(new DMXCommand(channel, value, cmd));
    // 최대 크기 초과시 오래된 것 제거
    while (commandHistory.size() > maxHistorySize) {
      commandHistory.remove(0);
    }
    return;
  }

  println("SEND → " + cmd);
  myPort.write(cmd);

  // DMX 출력 모니터에 추가 (원본 cmd 포함)
  commandHistory.add(new DMXCommand(channel, value, cmd));

  // 최대 크기 초과시 오래된 것 제거
  while (commandHistory.size() > maxHistorySize) {
    commandHistory.remove(0);
  }
}

// 수동 CMD 전송 (파싱 및 검증)
void sendManualCommand(String input) {
  input = input.trim().toUpperCase();

  // "CH{숫자}={숫자}" 형식 파싱
  if (input.startsWith("CH") && input.contains("=")) {
    try {
      // CH 제거
      String rest = input.substring(2);
      String[] parts = rest.split("=");

      if (parts.length == 2) {
        int channel = int(parts[0].trim());
        int value = int(parts[1].trim());

        // 유효성 검사
        if (channel >= 1 && channel <= 18 && value >= 0 && value <= 255) {
          sendDMX(channel, value);
          println("✓ Manual CMD 성공: CH" + channel + "=" + value);
        } else {
          println("✗ 에러: 유효하지 않은 범위 (채널: 1-18, 값: 0-255)");
        }
      } else {
        println("✗ 에러: 잘못된 형식 (예: CH5=200)");
      }
    } catch (Exception e) {
      println("✗ 에러: 파싱 실패 - " + e.getMessage());
    }
  } else {
    // Raw 명령어로 직접 전송 (검증 없이)
    String cmd = input + "\n";
    if (myPort != null) {
      myPort.write(cmd);
      println("Raw CMD 전송: " + input);
    } else {
      println("경고: 시리얼 연결 없음 - " + input);
    }
  }
}

// ============================================
// 모든 채널 초기화 (기본값으로 설정)
// ============================================
void resetAllChannels() {
  println("🔄 모든 채널 기본값으로 초기화 시작...");

  // 각 채널을 기본값으로 설정
  for (int ch = 1; ch <= 18; ch++) {
    int defaultValue = defaultChannelValues[ch - 1];
    sendDMX(ch, defaultValue);
    delay(5);  // 시리얼 오버플로우 방지
  }

  // UI 변수들도 기본값으로 재설정
  panValue = 127;
  tiltValue = 127;
  xySpeed = 128;
  dimmer = 0;
  strobeMode = 0;
  strobeSpeed = 128;
  colorMode = 0;
  colorValue = 0;
  colorEffect = 0;
  staticGobo = 0;
  rotationGobo = 0;
  goboRotation = 0;
  focus = 128;
  zoom = 128;
  prismOn = false;
  prismRotation = 0;
  frostOn = false;
  autoProgram = 0;

  println("✓ 모든 채널이 기본값으로 초기화되었습니다");
}

// ============================================
// 키프레임 클래스 (Phase 3 - Video Sequencer)
// ============================================
class Keyframe {
  float timestamp;  // 비디오 시간 (초)
  int[] dmxValues;  // 18채널 DMX 값 (0-255)

  Keyframe(float t, int[] values) {
    timestamp = t;
    dmxValues = values.clone();  // 배열 복사
  }
}

// ============================================
// DMX Command 클래스 (출력 모니터용)
// ============================================
class DMXCommand {
  int channel;
  int value;
  float timestamp;  // 프로그램 시작 후 경과 시간 (초)
  String rawCommand; // 원본 cmd 문자열

  DMXCommand(int ch, int val, String raw) {
    this.channel = ch;
    this.value = val;
    this.rawCommand = raw.trim();  // 개행/공백 제거
    this.timestamp = millis() / 1000.0;  // 밀리초 → 초
  }

  // 타임스탬프 포맷팅: [MM:SS.mmm]
  String getTimestamp() {
    int minutes = int(timestamp / 60);
    float seconds = timestamp % 60;
    return "[" + nf(minutes, 2) + ":" + nf(seconds, 5, 3) + "]";
  }

  // 채널명 가져오기
  String getChannelName() {
    if (channel >= 1 && channel <= 18) {
      return channelNames[channel - 1];
    }
    return "Unknown";
  }

  // 원본 명령어 가져오기
  String getRawCommand() {
    return rawCommand;
  }
}

// ============================================
// 비디오 로드 및 재생
// ============================================
void loadVideo() {
  try {
    movie = new Movie(this, videoPath);
    println("✓ 비디오 로드 성공: " + videoPath);
  } catch (Exception e) {
    println("✗ 에러: 비디오 파일을 열 수 없습니다");
    println("  경로: data/" + videoPath);
    println("  원인: " + e.getMessage());
    println("  → data/ 폴더에 video.mp4 파일이 있는지 확인하세요");
    movie = null;
  }
}

// Processing 비디오 라이브러리가 새 프레임을 읽을 때 자동 호출
void movieEvent(Movie m) {
  m.read();
}

// ============================================
// 재생 컨트롤 버튼 (Stop, Play, Pause)
// ============================================
void drawPlaybackControls(int x, int y) {
  int btnW = 40;
  int btnH = 40;
  int spacing = 10;

  // Stop 버튼
  drawControlButton(x, y, btnW, btnH, "■", !isPlaying);

  // Play 버튼
  drawControlButton(x + btnW + spacing, y, btnW, btnH, "▶", isPlaying);

  // Pause 버튼
  drawControlButton(x + (btnW + spacing) * 2, y, btnW, btnH, "⏸", false);
}

void drawControlButton(int x, int y, int w, int h, String label, boolean active) {
  boolean hover = mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h;

  // 배경
  if (active) {
    fill(100, 150, 100);
    stroke(150, 255, 150);
  } else if (hover) {
    fill(80, 80, 120);
    stroke(150, 150, 255);
  } else {
    fill(60);
    stroke(100);
  }
  strokeWeight(1);
  rect(x, y, w, h, 3);

  // 레이블
  fill(255);
  textSize(18);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2);
  textAlign(LEFT, BASELINE);
}

// ============================================
// 타임라인 시크바
// ============================================
void drawTimelineSeekbar(int x, int y, int w) {
  int h = 30;

  // 배경 (시크바 트랙)
  fill(40);
  stroke(80);
  strokeWeight(1);
  rect(x, y, w, h, 3);

  // 시간 정보
  float duration = (movie != null && movie.duration() > 0) ? movie.duration() : 0;
  videoTime = (movie != null) ? movie.time() : 0;

  // 진행 바
  if (duration > 0) {
    float progress = videoTime / duration;
    fill(100, 150, 255, 100);
    noStroke();
    rect(x, y, w * progress, h, 3);

    // 현재 위치 핸들
    float handleX = x + w * progress;
    fill(100, 200, 255);
    stroke(150, 220, 255);
    strokeWeight(2);
    rect(handleX - 4, y - 5, 8, h + 10, 3);
  }

  // 키프레임 마커
  drawKeyframeMarkers(x, y, w, h, duration);

  // 시간 텍스트
  noStroke();
  fill(200);
  textSize(11);
  textAlign(CENTER, CENTER);
  String timeText = formatTime(videoTime) + " / " + formatTime(duration);
  text(timeText, x + w/2, y + h/2);
  textAlign(LEFT, BASELINE);
}

// 키프레임 마커 그리기
void drawKeyframeMarkers(int x, int y, int w, int h, float duration) {
  if (duration == 0) return;

  for (int i = 0; i < timeline.size(); i++) {
    Keyframe kf = timeline.get(i);
    float markerX = x + w * (kf.timestamp / duration);

    // 선택된 키프레임은 다른 색
    if (i == selectedKeyframe) {
      fill(255, 200, 100);
    } else {
      fill(100, 255, 100);
    }

    // 삼각형 마커 (크기 2배 확대)
    noStroke();
    triangle(markerX, y - 16, markerX - 8, y - 4, markerX + 8, y - 4);
  }
}

// 시간 포맷팅 (MM:SS)
String formatTime(float seconds) {
  if (seconds < 0) seconds = 0;
  int mins = int(seconds / 60);
  int secs = int(seconds % 60);
  return nf(mins, 2) + ":" + nf(secs, 2);
}

// ============================================
// 타임라인 마우스 클릭 처리
// ============================================
boolean handleTimelineClick() {
  if (movie == null) return false;

  int tlY = TIMELINE_Y;
  int previewX = 30;
  int previewW = 80;

  // 재생 컨트롤 버튼 좌표
  int btnStartX = previewX + previewW + 20;
  int btnY = tlY + 10;
  int btnW = 40;
  int btnH = 40;
  int spacing = 10;

  // Stop 버튼
  if (mouseX > btnStartX && mouseX < btnStartX + btnW &&
      mouseY > btnY && mouseY < btnY + btnH) {
    stopVideo();
    return true;
  }

  // Play 버튼
  int playX = btnStartX + btnW + spacing;
  if (mouseX > playX && mouseX < playX + btnW &&
      mouseY > btnY && mouseY < btnY + btnH) {
    playVideo();
    return true;
  }

  // Pause 버튼
  int pauseX = playX + btnW + spacing;
  if (mouseX > pauseX && mouseX < pauseX + btnW &&
      mouseY > btnY && mouseY < btnY + btnH) {
    pauseVideo();
    return true;
  }

  // 시크바 클릭 (시간 점프 + 키프레임 선택)
  int seekX = 300;
  int seekY = tlY + 15;
  int seekW = 980;
  int seekH = 30;
  if (mouseX > seekX && mouseX < seekX + seekW &&
      mouseY > seekY - 10 && mouseY < seekY + seekH) {
    // 키프레임 마커 클릭 확인 (위쪽 삼각형 영역)
    if (mouseY < seekY) {
      float duration = movie.duration();
      for (int i = 0; i < timeline.size(); i++) {
        Keyframe kf = timeline.get(i);
        float markerX = seekX + seekW * (kf.timestamp / duration);
        if (abs(mouseX - markerX) < 10) {  // 클릭 영역 확대 (5 → 10)
          selectedKeyframe = i;
          // 키프레임 값 즉시 적용
          applyKeyframe(kf);
          println("🎯 키프레임 선택 & 적용: #" + (i + 1) + " @ " + formatTime(kf.timestamp));
          return true;
        }
      }
    }

    // 시크바 클릭 (시간 점프)
    float clickPos = (mouseX - seekX) / float(seekW);
    float newTime = clickPos * movie.duration();
    movie.jump(newTime);
    selectedKeyframe = -1;  // 선택 해제
    // 이동한 시간의 키프레임 값 즉시 적용
    updateDMXFromTimeline();
    println("⏩ 비디오 시간 이동: " + formatTime(newTime));
    return true;
  }

  // Add Keyframe 버튼
  int kfX = 1290;
  int kfY = tlY + 35;
  int kfW = 35;
  int kfH = 20;
  if (mouseX > kfX && mouseX < kfX + kfW &&
      mouseY > kfY && mouseY < kfY + kfH) {
    addKeyframe();
    return true;
  }

  // Delete Keyframe 버튼
  int delX = kfX + kfW + 5;
  if (mouseX > delX && mouseX < delX + kfW &&
      mouseY > kfY && mouseY < kfY + kfH) {
    deleteSelectedKeyframe();
    return true;
  }

  return false;
}

// 비디오 재생
void playVideo() {
  if (movie == null) return;
  movie.play();
  isPlaying = true;
  println("▶ 비디오 재생 시작");
}

// 비디오 일시정지
void pauseVideo() {
  if (movie == null) return;
  movie.pause();
  isPlaying = false;
  println("⏸ 비디오 일시정지");
}

// 비디오 정지
void stopVideo() {
  if (movie == null) return;
  movie.stop();
  movie.jump(0);
  isPlaying = false;
  videoTime = 0;
  println("■ 비디오 정지");
}

// ============================================
// 키프레임 추가/삭제
// ============================================
void addKeyframe() {
  if (movie == null) return;

  float currentTime = movie.time();

  // 현재 DMX 채널 값을 배열로 복사
  int[] values = new int[18];
  for (int i = 0; i < 18; i++) {
    values[i] = dmxChannels[i];
  }

  // 새 키프레임 생성
  Keyframe newKF = new Keyframe(currentTime, values);

  // 시간 순서대로 삽입
  int insertPos = 0;
  for (int i = 0; i < timeline.size(); i++) {
    if (timeline.get(i).timestamp < currentTime) {
      insertPos = i + 1;
    }
  }

  timeline.add(insertPos, newKF);
  selectedKeyframe = insertPos;

  println("✅ 키프레임 추가: #" + (insertPos + 1) + " @ " + formatTime(currentTime) + " (" + timeline.size() + " 개)");

  // 자동 저장
  saveSequence("sequence.json");
}

void deleteSelectedKeyframe() {
  if (selectedKeyframe < 0 || selectedKeyframe >= timeline.size()) {
    println("⚠️ 삭제할 키프레임이 선택되지 않았습니다");
    return;
  }

  Keyframe kf = timeline.get(selectedKeyframe);
  println("🗑️ 키프레임 삭제: #" + (selectedKeyframe + 1) + " @ " + formatTime(kf.timestamp));

  timeline.remove(selectedKeyframe);
  selectedKeyframe = -1;  // 선택 해제

  println("   남은 키프레임: " + timeline.size() + " 개");

  // 자동 저장
  saveSequence("sequence.json");
}

// ============================================
// 타임라인 동기화 (키프레임 보간)
// ============================================
void updateDMXFromTimeline() {
  if (timeline.size() == 0 || movie == null) return;

  float currentTime = movie.time();

  // 정확히 일치하는 키프레임 찾기
  for (int i = 0; i < timeline.size(); i++) {
    Keyframe kf = timeline.get(i);
    if (abs(kf.timestamp - currentTime) < 0.1) {
      applyKeyframe(kf);
      return;
    }
  }

  // 현재 시간 사이의 두 키프레임 찾기 (보간용)
  Keyframe prevKF = null;
  Keyframe nextKF = null;

  for (int i = 0; i < timeline.size(); i++) {
    Keyframe kf = timeline.get(i);
    if (kf.timestamp <= currentTime) {
      prevKF = kf;
    } else if (kf.timestamp > currentTime && nextKF == null) {
      nextKF = kf;
      break;
    }
  }

  // 보간 처리
  if (prevKF != null && nextKF != null) {
    // 선형 보간
    float t = (currentTime - prevKF.timestamp) / (nextKF.timestamp - prevKF.timestamp);
    interpolateKeyframes(prevKF, nextKF, t);
  } else if (prevKF != null) {
    // 마지막 키프레임 유지
    applyKeyframe(prevKF);
  } else if (nextKF != null) {
    // 첫 키프레임 전에는 첫 키프레임 값 사용
    applyKeyframe(nextKF);
  }
}

// 키프레임 적용 (변경된 채널만 전송)
void applyKeyframe(Keyframe kf) {
  for (int i = 0; i < 18; i++) {
    int newValue = kf.dmxValues[i];
    // 값이 변경된 경우만 전송
    if (dmxChannels[i] != newValue) {
      dmxChannels[i] = newValue;
      sendDMX(i + 1, newValue);
    }
  }

  // UI 변수 동기화
  syncUIFromDMX();
}

// 두 키프레임 사이 보간 (변경된 채널만 전송)
void interpolateKeyframes(Keyframe kf1, Keyframe kf2, float t) {
  t = constrain(t, 0, 1);  // 0~1 범위 제한

  for (int i = 0; i < 18; i++) {
    int val1 = kf1.dmxValues[i];
    int val2 = kf2.dmxValues[i];
    int interpolated = int(lerp(val1, val2, t));

    // 값이 변경된 경우만 전송
    if (dmxChannels[i] != interpolated) {
      dmxChannels[i] = interpolated;
      sendDMX(i + 1, interpolated);
    }
  }

  // UI 변수 동기화
  syncUIFromDMX();
}

// ============================================
// 시퀀스 저장/로드 (JSON)
// ============================================
void saveSequence(String filename) {
  if (timeline.size() == 0) {
    println("⚠️ 저장할 키프레임이 없습니다");
    return;
  }

  JSONArray jsonTimeline = new JSONArray();

  for (int i = 0; i < timeline.size(); i++) {
    Keyframe kf = timeline.get(i);
    JSONObject jsonKF = new JSONObject();

    jsonKF.setFloat("timestamp", kf.timestamp);

    JSONArray jsonValues = new JSONArray();
    for (int ch = 0; ch < 18; ch++) {
      jsonValues.setInt(ch, kf.dmxValues[ch]);
    }
    jsonKF.setJSONArray("dmxValues", jsonValues);

    jsonTimeline.setJSONObject(i, jsonKF);
  }

  saveJSONArray(jsonTimeline, "data/" + filename);
  println("💾 시퀀스 저장 완료: data/" + filename + " (" + timeline.size() + " 키프레임)");
}

void loadSequence(String filename) {
  try {
    JSONArray jsonTimeline = loadJSONArray("data/" + filename);

    timeline.clear();
    selectedKeyframe = -1;

    for (int i = 0; i < jsonTimeline.size(); i++) {
      JSONObject jsonKF = jsonTimeline.getJSONObject(i);
      float timestamp = jsonKF.getFloat("timestamp");

      JSONArray jsonValues = jsonKF.getJSONArray("dmxValues");
      int[] dmxValues = new int[18];
      for (int ch = 0; ch < 18; ch++) {
        dmxValues[ch] = jsonValues.getInt(ch);
      }

      Keyframe kf = new Keyframe(timestamp, dmxValues);
      timeline.add(kf);
    }

    println("📂 시퀀스 로드 완료: data/" + filename + " (" + timeline.size() + " 키프레임)");
  } catch (Exception e) {
    println("✗ 에러: 시퀀스 파일을 열 수 없습니다");
    println("  경로: data/" + filename);
    println("  원인: " + e.getMessage());
  }
}
