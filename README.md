# DMX 30-Channel Multi-Device Controller

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Processing](https://img.shields.io/badge/Processing-4.x-blue?logo=processing-foundation)
![Arduino](https://img.shields.io/badge/Arduino-C++-00979D?logo=arduino)
![DMX](https://img.shields.io/badge/DMX512-30_Channels-orange)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)

Processing 기반 30채널 DMX 조명 컨트롤러. 비디오 타임라인과 동기화된 키프레임 시퀀서를 지원합니다.

## 지원 장치

| DMX 채널 | 장치 | 기능 |
|----------|------|------|
| CH1-18 | Moving Head | Pan, Tilt, Dimmer, Strobe, Color, Gobo, Focus, Zoom, Prism, Frost |
| CH19-25 | RGBW PAR Light | Dimmer, R, G, B, W, Strobe, Auto/Sound |
| CH26-27 | Ellipsoidal 1 | Dimmer, Strobe |
| CH28-29 | Ellipsoidal 2 | Dimmer, Strobe |
| CH30 | Fog Machine | Output |

## 요구사항

- [Processing 4](https://processing.org/download)
- [Arduino IDE](https://www.arduino.cc/en/software) 또는 Arduino CLI
- Arduino Uno/Leonardo + MAX485 모듈
- DMXSerial 라이브러리

## 설치

### 1. Arduino DMX 인터페이스

```bash
# Arduino CLI 사용 시
arduino-cli lib install DMXSerial
arduino-cli compile --fqbn arduino:avr:leonardo arduino_dmx
arduino-cli upload -p /dev/cu.usbmodem11301 --fqbn arduino:avr:leonardo arduino_dmx
```

또는 Arduino IDE에서:
1. `arduino_dmx/arduino_dmx.ino` 열기
2. 라이브러리 매니저에서 "DMXSerial" 설치
3. 보드 선택 후 업로드

### 2. Processing 앱

1. `dmx.pde`를 Processing IDE에서 열기
2. 시리얼 포트 확인 (기본: `/dev/tty.usbmodem11301`)
3. `Cmd+R` (Mac) / `Ctrl+R` (Windows)로 실행

## 사용법

### UI 탭

- **Position**: Pan/Tilt 2D 패드, XY Speed
- **Light**: Dimmer, Strobe, Color Wheel
- **Gobo**: Static/Rotation Gobo 선택
- **Beam**: Focus, Zoom, Prism
- **Effects**: Frost, Auto Program
- **PAR**: RGBW PAR 조명 제어
- **Ellip**: Ellipsoidal 조명 2대 제어
- **Fog**: 포그 머신 출력

### 키보드 단축키

| 키 | 기능 |
|----|------|
| `K` | 현재 시간에 키프레임 추가 |
| `S` | 키프레임 변경사항 저장 |
| `Delete` | 선택된 키프레임 삭제 |
| `Space` | 비디오 재생/일시정지 |
| `F1-F12` | 프리셋 불러오기 |
| `Shift+F1-F12` | 프리셋 저장 |

### 타임라인 시퀀서

1. 비디오 파일을 `data/video.mp4`에 배치
2. 비디오 재생 중 원하는 시점에서 `K`로 키프레임 추가
3. 슬라이더로 DMX 값 조정
4. `S`로 저장
5. 키프레임 간 전환 모드 선택 (Instant/Fade)

## 시리얼 프로토콜

```
CH{channel}={value}\n
```

예시:
- `CH1=127\n` - Pan을 127로 설정
- `CH19=255\n` - PAR Dimmer를 최대로

## 하드웨어 연결

```
Arduino          MAX485
  TX  ─────────▶  DI
  5V  ─────────▶  VCC
  GND ─────────▶  GND
  5V  ─────────▶  DE, RE (Enable)

MAX485           DMX 장치
  A   ─────────▶  Data+
  B   ─────────▶  Data-
  GND ─────────▶  GND
```

## 파일 구조

```
dmx/
├── dmx.pde              # Processing 메인 앱
├── arduino_dmx/
│   └── arduino_dmx.ino  # Arduino DMX 컨트롤러
├── data/
│   ├── sequence.json    # 키프레임 시퀀스
│   └── video.mp4        # 타임라인 비디오
├── CLAUDE.md            # 개발 문서
└── README.md
```

## License

MIT
