import processing.serial.*;

Serial myPort;

// ============================================
// DMX 채널 데이터 (18채널)
// ============================================
int[] dmxChannels = new int[18];

// ============================================
// 프리셋 시스템 (F1~F12)
// ============================================
int[][] presets = new int[12][18];
String[] presetNames = new String[12];

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
// 타임라인/시퀀서 변수 (Phase 3에서 구현)
// ============================================
boolean isRecording = false;
boolean isPlaying = false;
ArrayList<Keyframe> timeline = new ArrayList<Keyframe>();

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

void setup() {
  size(1800, 750);

  // 시리얼 포트 연결
  printArray(Serial.list());
  myPort = new Serial(this, "/dev/tty.usbmodem1201", 115200);

  // 초기화
  for (int i = 0; i < 18; i++) {
    dmxChannels[i] = 0;
  }

  // 프리셋 이름 초기화
  for (int i = 0; i < 12; i++) {
    presetNames[i] = "Preset " + (i + 1);
  }
}

void draw() {
  background(25);

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

  // 하단 타임라인 영역 (Phase 3에서 구현)
  drawTimelineArea();

  // 프리셋 버튼 영역
  drawPresetButtons();

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
  int padY = yPos + 60;
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

  // 값 표시 영역 (패드 아래 20px 마진)
  int valueY = padY + padSize + 20;
  fill(255);
  textSize(14);

  // Pan 값
  text("Pan:", padX, valueY + 15);
  drawValueBox(padX + 50, valueY, int(panValue), null);
  text("(" + nf(map(panValue, 0, 255, 0, 540), 0, 1) + "°)", padX + 110, valueY + 15);

  // Tilt 값
  text("Tilt:", padX, valueY + 45);
  drawValueBox(padX + 50, valueY + 30, int(tiltValue), null);
  text("(" + nf(map(tiltValue, 0, 255, 0, 270), 0, 1) + "°)", padX + 110, valueY + 45);

  // 오른쪽 컨트롤 영역
  int rightX = padX + padSize + 60;
  int rightY = padY;

  // Fine 모드 토글
  drawCheckbox(rightX, rightY, "Fine Mode", fineMode);

  // XY Speed (Fine Mode 아래 40px 마진)
  int speedY = rightY + 50;
  fill(255);
  textSize(14);
  text("XY Speed:", rightX, speedY);
  drawSlider(rightX, speedY + 10, 250, "", xySpeed, 0, 255);
  drawValueBox(rightX + 260, speedY + 10, xySpeed, null);

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
  int startX = 50;
  int startY = yPos + 60;

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
  fill(255);
  textSize(14);
  text("Color Effect", colorX, effectY);
  drawSlider(colorX, effectY + 10, 220, "", colorEffect, 0, 255);
  drawValueBox(colorX + 230, effectY + 10, colorEffect, null);
}

// ============================================
// Gobo 탭 (CH10-12)
// ============================================
void drawGoboTab(int yPos) {
  fill(255);
  textSize(18);
  text("Gobo Control (Pattern Selection)", 30, yPos + 20);

  int margin = 30;
  int startX = 50;
  int startY = yPos + 60;

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
  fill(255);
  textSize(14);
  text("Gobo Rotation (CH12)", startX, rotSliderY);
  drawSlider(startX, rotSliderY + 10, 350, "", goboRotation, 0, 255);
  drawValueBox(startX + 360, rotSliderY + 10, goboRotation, null);
}

// ============================================
// Beam 탭 (CH13-16)
// ============================================
void drawBeamTab(int yPos) {
  fill(255);
  textSize(18);
  text("Beam Control (Focus/Zoom/Prism)", 30, yPos + 20);

  int margin = 30;
  int startX = 50;
  int startY = yPos + 60;

  // Focus 슬라이더
  fill(255);
  textSize(14);
  text("Focus (Hazy ← → Clear)", startX, startY);
  drawSlider(startX, startY + 10, 350, "", focus, 0, 255);
  drawValueBox(startX + 360, startY + 10, focus, null);

  // Zoom 슬라이더 (Focus 아래 + 마진)
  int zoomY = startY + 70;
  fill(255);
  textSize(14);
  text("Zoom (Narrow ← → Wide)", startX, zoomY);
  drawSlider(startX, zoomY + 10, 350, "", zoom, 0, 255);
  drawValueBox(startX + 360, zoomY + 10, zoom, null);

  // Prism 섹션 (Zoom 아래 + 마진)
  int prismY = zoomY + 70;
  drawCheckbox(startX, prismY, "Prism On/Off", prismOn);

  // Prism Rotation (Prism 체크박스 아래)
  if (prismOn) {
    int rotY = prismY + 40;
    fill(255);
    textSize(14);
    text("Prism Rotation", startX, rotY);
    drawSlider(startX, rotY + 10, 350, "", prismRotation, 0, 255);
    drawValueBox(startX + 360, rotY + 10, prismRotation, null);
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
  int startX = 50;
  int startY = yPos + 60;

  // Frost 토글
  drawCheckbox(startX, startY, "Frost Effect", frostOn);

  // Auto Program (Frost 아래 + 마진)
  int autoY = startY + 50;
  fill(255);
  textSize(14);
  text("Auto Program", startX, autoY);
  drawSlider(startX, autoY + 10, 350, "", autoProgram, 0, 131);
  drawValueBox(startX + 360, autoY + 10, autoProgram, null);
}

// ============================================
// DMX 출력 모니터
// ============================================
void drawDMXMonitor() {
  int monitorY = 430;
  int monitorHeight = 140;

  // 배경
  fill(30);
  stroke(100);
  strokeWeight(1);
  rect(20, monitorY, 1760, monitorHeight);

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
}

// ============================================
// 타임라인 영역 (Phase 3에서 구현)
// ============================================
void drawTimelineArea() {
  int tlY = 580;

  fill(50);
  stroke(100);
  rect(20, tlY, 1760, 60);

  fill(150);
  textSize(14);
  text("🎬 Timeline / Sequencer (Coming in Phase 3)", 30, tlY + 20);
}

// ============================================
// 프리셋 버튼 영역
// ============================================
void drawPresetButtons() {
  int presetY = 660;

  fill(255);
  textSize(14);
  text("💾 Presets (Shift+F1~F12 = Save, F1~F12 = Load):", 20, presetY);

  for (int i = 0; i < 12; i++) {
    int btnX = 20 + i * 145;
    int btnY = presetY + 10;

    fill(60);
    stroke(100);
    rect(btnX, btnY, 130, 30, 3);

    fill(200);
    textSize(12);
    textAlign(CENTER, CENTER);
    text("F" + (i + 1), btnX + 65, btnY + 15);
    textAlign(LEFT, BASELINE);
  }
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

  // 슬라이더 바
  fill(60);
  stroke(100);
  rect(x, y + 10, w, 20);

  // 핸들
  float handleX = map(value, minVal, maxVal, x, x + w);
  fill(100, 150, 255);
  noStroke();
  rect(handleX - 5, y + 5, 10, 30);
}

// 세로 슬라이더
void drawVerticalSlider(int x, int y, int w, int h, String label, int value, int minVal, int maxVal) {
  // 레이블
  fill(255);
  textSize(14);
  text(label, x, y - 10);

  // 슬라이더 바
  fill(60);
  stroke(100);
  rect(x, y, w, h);

  // 핸들
  float handleY = map(value, minVal, maxVal, y + h, y);
  fill(100, 150, 255);
  noStroke();
  rect(x, handleY - 5, w, 10);

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
  // 입력 모드일 때는 클릭 무시
  if (isInputMode) {
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
  int padY = yPos + 60;
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
  int startX = 50;
  int startY = yPos + 60;

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
  int startX = 50;
  int startY = yPos + 60;
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
  int startX = 50;
  int startY = yPos + 60;

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
  int startX = 50;
  int startY = yPos + 60;
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
  int padY = yPos + 60;
  int padSize = 300;
  int rightX = padX + padSize + 60;
  int rightY = padY;

  // Fine 모드 체크박스
  if (mouseX > rightX && mouseX < rightX + 20 &&
      mouseY > rightY && mouseY < rightY + 20) {
    fineMode = !fineMode;
  }
}

void handlePositionDrags(int yPos) {
  int padX = 50;
  int padY = yPos + 60;
  int padSize = 300;

  // XY 패드 드래그
  if (mouseX > padX && mouseX < padX + padSize &&
      mouseY > padY && mouseY < padY + padSize) {
    panValue = constrain(map(mouseX, padX, padX + padSize, 0, 255), 0, 255);
    tiltValue = constrain(map(mouseY, padY + padSize, padY, 0, 255), 0, 255);

    updateDMXChannel(1, int(panValue));
    updateDMXChannel(3, int(tiltValue));
  }

  // XY Speed 슬라이더
  int rightX = padX + padSize + 60;
  int rightY = padY;
  int speedY = rightY + 50;
  int sliderW = 250;
  if (mouseX > rightX && mouseX < rightX + sliderW &&
      mouseY > speedY + 10 && mouseY < speedY + 30) {
    xySpeed = int(constrain(map(mouseX, rightX, rightX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(5, xySpeed);
  }
}

// ============================================
// Light 탭 인터랙션
// ============================================
void handleLightClicks(int yPos) {
  int startX = 50;
  int startY = yPos + 60;
  int strobeX = startX + 160;

  // Strobe 모드 버튼
  for (int i = 0; i < 3; i++) {
    int btnY = startY + 10 + i * 40;
    if (mouseX > strobeX && mouseX < strobeX + 80 &&
        mouseY > btnY && mouseY < btnY + 30) {
      strobeMode = i;
      updateStrobeChannel();
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
    }
  }
}

void handleLightDrags(int yPos) {
  int startX = 50;
  int startY = yPos + 60;

  // Dimmer 슬라이더 (세로)
  if (mouseX > startX && mouseX < startX + 60 &&
      mouseY > startY && mouseY < startY + 240) {
    dimmer = int(constrain(map(mouseY, startY + 240, startY, 0, 255), 0, 255));
    updateDMXChannel(6, dimmer);
  }

  // Strobe Speed 슬라이더
  if (strobeMode == 2) {
    int strobeX = startX + 160;
    int sliderW = 150;
    if (mouseX > strobeX && mouseX < strobeX + sliderW &&
        mouseY > startY + 150 && mouseY < startY + 170) {
      strobeSpeed = int(constrain(map(mouseX, strobeX, strobeX + sliderW, 8, 250), 8, 250));
      updateStrobeChannel();
    }
  }

  // Color Effect 슬라이더
  int strobeX = startX + 160;
  int colorX = strobeX + 250;
  int effectY = startY + 140;
  int sliderW = 220;
  if (mouseX > colorX && mouseX < colorX + sliderW &&
      mouseY > effectY + 10 && mouseY < effectY + 30) {
    colorEffect = int(constrain(map(mouseX, colorX, colorX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(9, colorEffect);
  }
}

// ============================================
// Gobo 탭 인터랙션
// ============================================
void handleGoboClicks(int yPos) {
  int startX = 50;
  int startY = yPos + 60;

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
    }
  }
}

void handleGoboDrags(int yPos) {
  int startX = 50;
  int startY = yPos + 60;
  int rotSliderY = startY + 200;
  int sliderW = 350;

  // Gobo Rotation 슬라이더
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > rotSliderY + 10 && mouseY < rotSliderY + 30) {
    goboRotation = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(12, goboRotation);
  }
}

// ============================================
// Beam 탭 인터랙션
// ============================================
void handleBeamClicks(int yPos) {
  int startX = 50;
  int startY = yPos + 60;
  int zoomY = startY + 70;
  int prismY = zoomY + 70;

  // Prism 체크박스
  if (mouseX > startX && mouseX < startX + 20 &&
      mouseY > prismY && mouseY < prismY + 20) {
    prismOn = !prismOn;
    updateDMXChannel(15, prismOn ? 128 : 0);
  }
}

void handleBeamDrags(int yPos) {
  int startX = 50;
  int startY = yPos + 60;
  int sliderW = 350;

  // Focus 슬라이더
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > startY + 10 && mouseY < startY + 30) {
    focus = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(13, focus);
  }

  // Zoom 슬라이더
  int zoomY = startY + 70;
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > zoomY + 10 && mouseY < zoomY + 30) {
    zoom = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
    updateDMXChannel(14, zoom);
  }

  // Prism Rotation
  if (prismOn) {
    int prismY = zoomY + 70;
    int rotY = prismY + 40;
    if (mouseX > startX && mouseX < startX + sliderW &&
        mouseY > rotY + 10 && mouseY < rotY + 30) {
      prismRotation = int(constrain(map(mouseX, startX, startX + sliderW, 0, 255), 0, 255));
      updateDMXChannel(16, prismRotation);
    }
  }
}

// ============================================
// Effects 탭 인터랙션
// ============================================
void handleEffectsClicks(int yPos) {
  int startX = 50;
  int startY = yPos + 60;

  // Frost 체크박스
  if (mouseX > startX && mouseX < startX + 20 &&
      mouseY > startY && mouseY < startY + 20) {
    frostOn = !frostOn;
    updateDMXChannel(17, frostOn ? 128 : 0);
  }
}

void handleEffectsDrags(int yPos) {
  int startX = 50;
  int startY = yPos + 60;
  int autoY = startY + 50;
  int sliderW = 350;

  // Auto Program 슬라이더
  if (mouseX > startX && mouseX < startX + sliderW &&
      mouseY > autoY + 10 && mouseY < autoY + 30) {
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

  // F1~F12 (키코드 112-123)
  if (keyCode >= 112 && keyCode <= 123) {
    int presetNum = keyCode - 112;

    if (keyPressed && key == CODED && keyEvent.isShiftDown()) {
      // 저장
      for (int i = 0; i < 18; i++) {
        presets[presetNum][i] = dmxChannels[i];
      }
      println("Preset F" + (presetNum + 1) + " SAVED");
    } else {
      // 로드
      for (int i = 0; i < 18; i++) {
        dmxChannels[i] = presets[presetNum][i];
        sendDMX(i + 1, dmxChannels[i]);
      }

      // UI 변수 동기화
      syncUIFromDMX();
      println("Preset F" + (presetNum + 1) + " LOADED");
    }
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
  println("SEND → " + cmd);
  myPort.write(cmd);

  // DMX 출력 모니터에 추가 (원본 cmd 포함)
  commandHistory.add(new DMXCommand(channel, value, cmd));

  // 최대 크기 초과시 오래된 것 제거
  while (commandHistory.size() > maxHistorySize) {
    commandHistory.remove(0);
  }
}

// ============================================
// 키프레임 클래스 (Phase 3에서 사용)
// ============================================
class Keyframe {
  float time;
  int[] values;

  Keyframe(float t, int[] v) {
    time = t;
    values = v.clone();
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
