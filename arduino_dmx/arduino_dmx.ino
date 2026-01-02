/*
 * DMX Controller - 30 Channel
 *
 * Processing에서 시리얼로 명령을 받아 DMX 출력
 * 명령 형식: CH{channel}={value}\n
 * 예: CH1=255\n, CH19=128\n
 *
 * 하드웨어:
 * - Arduino Uno/Mega
 * - MAX485 또는 RS485 모듈 (TX -> DI, DE/RE -> HIGH)
 * - DMX 출력: Pin 1 (TX)
 *
 * 라이브러리: DMXSerial (Arduino Library Manager에서 설치)
 */

#include <DMXSerial.h>

// 설정
#define DMX_CHANNELS 30      // 총 DMX 채널 수
#define SERIAL_BAUD 115200   // Processing과 통신 속도

// 시리얼 입력 버퍼
String inputBuffer = "";
bool commandReady = false;

void setup() {
  // DMX 마스터 모드로 초기화
  DMXSerial.init(DMXController);

  // 모든 채널 0으로 초기화
  for (int i = 1; i <= DMX_CHANNELS; i++) {
    DMXSerial.write(i, 0);
  }

  // 시리얼 통신 시작 (USB)
  Serial.begin(SERIAL_BAUD);

  // 시작 메시지
  Serial.println("DMX Controller Ready - 30 Channels");
  Serial.println("Command format: CH{1-30}={0-255}");
}

void loop() {
  // 시리얼 데이터 수신
  while (Serial.available() > 0) {
    char c = Serial.read();

    if (c == '\n') {
      // 명령 완료
      commandReady = true;
    } else if (c != '\r') {
      // 버퍼에 추가 (캐리지 리턴 무시)
      inputBuffer += c;
    }
  }

  // 명령 처리
  if (commandReady) {
    processCommand(inputBuffer);
    inputBuffer = "";
    commandReady = false;
  }
}

void processCommand(String cmd) {
  // 명령 형식: CH{channel}={value}
  // 예: CH1=255, CH19=128

  cmd.trim();

  // CH로 시작하는지 확인
  if (!cmd.startsWith("CH")) {
    Serial.println("ERR: Invalid command");
    return;
  }

  // = 위치 찾기
  int eqPos = cmd.indexOf('=');
  if (eqPos < 0) {
    Serial.println("ERR: Missing =");
    return;
  }

  // 채널 번호 추출 (CH 다음부터 = 전까지)
  String channelStr = cmd.substring(2, eqPos);
  int channel = channelStr.toInt();

  // 값 추출 (= 다음부터)
  String valueStr = cmd.substring(eqPos + 1);
  int value = valueStr.toInt();

  // 범위 검증
  if (channel < 1 || channel > DMX_CHANNELS) {
    Serial.print("ERR: Channel out of range (1-");
    Serial.print(DMX_CHANNELS);
    Serial.println(")");
    return;
  }

  if (value < 0 || value > 255) {
    Serial.println("ERR: Value out of range (0-255)");
    return;
  }

  // DMX 출력
  DMXSerial.write(channel, value);

  // 확인 메시지
  Serial.print("OK: CH");
  Serial.print(channel);
  Serial.print("=");
  Serial.println(value);
}
