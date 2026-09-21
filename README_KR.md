## [English](/README.md) [简体中文](/README_CN.md) [日本語](/README_JP.md) [한국어](/README_KR.md)

# **thprac**
> thprac은 동방 프로젝트 슈팅 게임을 연습하기 위한 도구입니다.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/V7V7O03J4)

## [다운로드](https://github.com/touhouworldcup/thprac/releases/latest) - [베타 버전 다운로드](https://nightly.link/touhouworldcup/thprac/workflows/main/master/thprac.zip)
> 베타 버전은 다음 베타 버전이 아니라 다음 안정 버전으로만 업데이트됩니다.

## **목차**
* [다운로드](#downloading)
* [사용법](#usage)
* [호환성](#compatability)
* [기능](#features)
* [빠른 메뉴](#quick-menu)
* [고급 옵션](#advanced-options)
* [게임별 기능](#game-specific-features)
* [기여자](#credits)
* [소스에서 빌드하기](#building-from-source)
* [자주 묻는 질문](#faq)

## <a name="downloading"></a> **다운로드**
이 도구를 다운로드하려면 [최신 릴리스](https://github.com/touhouworldcup/thprac/releases/latest) 또는 [최신 베타 버전](https://nightly.link/touhouworldcup/thprac/workflows/main/master/thprac.zip)을 받으세요. 최신 베타 버전은 다음 베타 릴리스가 **아니라** 다음 안정 릴리스로 업데이트된다는 점에 유의하세요.

## <a name="usage"></a> **사용법**
이 도구는 여러 방법으로 사용할 수 있습니다. 대표적인 방법은 **실행 파일을 게임과 같은 폴더에 두기**, **게임을 실행한 다음 실행 파일 실행하기**, **thprac 런처 사용하기**입니다.

### **게임 폴더에서 thprac 사용하기**
**이 방법은 Steam 게임에서는 작동하지 않습니다.** `thprac.exe` 파일을 게임과 같은 폴더에 두면 thprac을 실행할 수 있습니다. 이 방법은 vpatch도 자동으로 감지합니다. 게임이 최신 버전으로 업데이트되어 있고 실행 파일 이름이 다음 중 하나인지 확인해야 합니다. 이 방법은 vpatch와도 함께 사용할 수 있습니다.
- thXX.exe (대부분의 게임)
- 東方紅魔郷.exe (Embodiment of Scarlet Devil)
- alcostg.exe (Uwabami Breakers)

### **게임 실행 후 thprac 사용하기**
**이 방법은 대부분의 실행 방식에서 작동합니다.** 먼저 원하는 방식(thcrap, vpatch, Steam 등)으로 게임을 실행한 다음 `thprac.exe`를 실행하세요. thprac이 실행 중인 게임을 감지하여 연결을 시도합니다. thprac이 적용된 것을 확인하려면 메뉴 화면으로 돌아가야 할 수도 있습니다.

### **런처로 thprac 사용하기**
다음 영상에서는 런처 사용법을 설명합니다.
[![thprac 2.0 빠른 개요](https://i.ytimg.com/vi/sRV4PDQceYo/maxresdefault.jpg)](https://www.youtube.com/watch?v=sRV4PDQceYo)

### 명령줄
다음 명령줄 옵션을 지원합니다.
- `<path to game exe>`: `thprac.exe <path to game exe>` 명령은 확인 메시지 없이 게임을 실행하고 thprac을 연결합니다. 따라서 동방 프로젝트 게임 실행 파일을 `thprac.exe` 위에 끌어다 놓아 thprac과 함께 실행할 수 있습니다. `<path to game exe>` 뒤에 명령줄 인수를 더 입력하면 해당 인수는 게임 실행 파일로 전달됩니다. ZUN은 명령줄 인수를 사용하지 않으므로 실제로 쓸모는 없습니다.
- `--attach <pid>`: 확인 메시지 없이 프로세스 ID가 `<pid>`인 프로세스에 thprac을 즉시 주입합니다.
- `--attach`(다른 플래그 없음): `thprac.exe --attach` 명령은 어떠한 확인 메시지도 표시하지 않고 처음 발견한 동방 프로젝트 게임 프로세스에 thprac을 연결합니다.
- `--without-vpatch`: vpatch가 자동으로 적용되지 않게 합니다.
- `--without-oilp`: OpenInputLagPatch가 자동으로 적용되지 않게 합니다.

마지막 두 플래그에 관한 참고 사항: 두 플래그를 모두 지정하지 않은 상태에서 vpatch와 OpenInputLagPatch가 모두 존재하면 OpenInputLagPatch가 우선 적용됩니다.

명령 예시:
```
thprac.exe --attach 1234
thprac.exe --attach
thprac.exe C:\Users\Name\Desktop\Games\Touhou\th17\th17.exe
thprac.exe --without-vpatch C:\Users\Name\Desktop\Games\Touhou\th12\th12.exe
```

## <a name="compatability"></a> **호환성**
thprac은 **Windows Vista** 이후의 모든 Windows 버전을 공식 지원합니다. Windows XP에서는 [One-Core-API](https://github.com/Skulltrail192/One-Core-API-Binaries)를 사용하면 작동할 수 있지만, **현재 별도로 테스트하고 있지는 않습니다.**

thprac은 **Wine** 및 Steam Deck과도 호환됩니다. 빠른 메뉴는 Steam Deck에서 사용하기 좋게 설계되었지만, 아직 테스트되지는 않았습니다.

## <a name="features"></a> **기능**

thprac은 모든 정규 작품과 Great Fairy Wars 및 Uwabami Breakers를 지원하는 향상된 연습 모드를 제공합니다.

![Unconnected Marketeers](https://user-images.githubusercontent.com/23106652/174433923-0a6069e7-d10d-4107-8f0d-f4a8a9d56976.png)

![Imperishable Night](https://user-images.githubusercontent.com/23106652/174433975-8f23b0b0-e48e-4be1-8cb7-d8e3e7ab6b8e.png)

thprac은 기존 연습 메뉴를 위 이미지와 같은 새로운 UI로 대체합니다. 일부 스펠에서는 페이즈를 선택하거나 특정 매개변수를 변경할 수 있습니다. 기존 연습 모드가 없는 게임(Uwabami Breakers, Great Fairy Wars 등)에는 "Start Game" 메뉴에 연습 메뉴가 추가됩니다.

![Uwabami Breakers](https://user-images.githubusercontent.com/23106652/174434103-5fee7a13-0254-4602-a468-42330b985bb2.png)
![Great Fairy Wars](https://user-images.githubusercontent.com/23106652/174434121-063142f2-ef3d-4721-ab96-a252343cdb0e.png)

이 메뉴는 키보드나 컨트롤러로 조작할 수 있습니다. **UP** 및 **DOWN** 키로 옵션을 선택하고 **LEFT** 및 **RIGHT** 키로 옵션 값을 변경하며 **SHOT** 키로 확정할 수 있습니다. 마우스로도 메뉴를 조작할 수 있습니다.

또한 thprac은 선택한 옵션을 저장하는 모든 리플레이에 자동으로 기록합니다. 리플레이를 재생할 때는 해당 옵션이 자동으로 적용됩니다. **thprac이 활성화된 상태에서 "Custom" 모드로 저장한 리플레이는 수정되지 않은 게임에서 작동하지 않습니다.**

## <a name="quick-menu"></a> **빠른 메뉴**
지원되는 모든 게임에서 **(동방 9 및 19 제외)** **`Backspace`** 키를 누르면 빠른 메뉴를 열 수 있습니다. 이 메뉴에는 기능(F) 키로 활성화할 수 있는 여러 옵션이 표시됩니다.

이 옵션들은 항상 클릭할 수 있습니다. 데스크톱 컴퓨터에서는 마우스로, Steam Deck에서는 왼쪽 엄지손가락으로 눌러 조작할 수 있습니다. Steam Deck에서 이 기능을 사용하려면 Steam Input에서 **`Backspace`** 키를 매핑하세요.

다른 키나 키 조합에 할당하고 싶다면 런처의 설정 탭에서 이 메뉴의 단축키를 변경할 수 있습니다.

![Unconnected Marketeers](https://user-images.githubusercontent.com/23106652/174434813-73748a66-0f6d-4c6e-9f3a-895a49b93434.png)
![Wily Beast and Weakest Creature](https://user-images.githubusercontent.com/23106652/174434834-6bd93104-1ed2-48ae-a440-9d9cb871ea03.png)

## <a name="advanced-options"></a> **고급 옵션**
지원되는 모든 게임에서 **(동방 9 및 19 제외)** **`F12`** 키를 누르면 고급 옵션을 열 수 있습니다. 고급 옵션에서는 게임 관련 수정 사항이나 패치 또는 기타 편의 기능을 제공할 수 있습니다.

빠른 메뉴와 마찬가지로 이 단축키도 런처의 설정 탭에서 변경할 수 있습니다.

![Imperishable Night](https://user-images.githubusercontent.com/23106652/174434977-683da583-324b-4bd5-8408-13373dfd5a93.png)
![Unconnected Marketeers](https://user-images.githubusercontent.com/23106652/174435006-e906d30d-0ef5-4930-ae57-1f0919beb5af.png)

## <a name="game-specific-features"></a> **게임별 기능**
### 100th BM - 웨이브 강제 지정
![100th Black Market](https://github.com/touhouworldcup/thprac/assets/23106652/02c55e5e-5c89-462f-beea-9ab07cbb1051)

"Custom" 모드로 thprac을 활성화하면 게임에서 웨이브를 선택하려 할 때 위 팝업이 나타납니다.

### PoFV - 도구
![Phantasmagoria of Flower View](https://user-images.githubusercontent.com/23106652/174434249-2bf1d70a-101c-4538-a4e6-8eeaf273dd88.png)

Match Mode로 게임을 시작할 때 "Mode" 선택 창에서 "Custom"을 선택할 수 있습니다. 그러면 게임에 이 창이 나타납니다. 원하는 대로 창을 이동하고 조정할 수 있습니다. 이 창은 고급 옵션을 대체하며 **`F12`** 키로 열 수 있습니다.

### UDoALG - 도구
![TH19 Tools](https://github.com/touhouworldcup/thprac/assets/23106652/a2cdb385-b61d-4111-af6b-b195e85bf18a)

UDoALG용이라는 점을 제외하면 PoFV 도구와 같습니다.

### EoSD - 일시 정지 메뉴
![TH06](https://user-images.githubusercontent.com/23106652/174436027-734d642a-300c-45ab-9591-b6219aca087b.png)

이제 "Exit"를 선택하면 리플레이를 저장할지 묻습니다.

**경고**: 이 방법으로 저장한 리플레이는 저장을 선택한 시점 이후에도 계속 진행됩니다. 플레이어 캐릭터는 움직이지 않고 사격도 하지 않습니다.

### EoSD, VD 및 이후 작품의 ESC + R 수정

## <a name="credits"></a> **기여자 (2022년 5월 27일 이후)**
- 개발: [32th System](https://www.youtube.com/channel/UChyVpooBi31k3xPbWYsoq3w), [muter3000](https://github.com/muter3000), [zero318](https://github.com/zero318), [Lmocinemod](https://github.com/Lmocinemod), [Cao Minh](https://github.com/hoangcaominh), [raviddog](https://github.com/raviddog)
- 중국어 번역: [CrestedPeak9](https://twitter.com/CrestedPeak9), maksim71_doll, DeepL
- 일본어 번역: [Yu-miya](https://www.twitch.tv/toho_yumiya), [SOC](https://github.com/soc-3), [wefma](https://github.com/wefma), CyrusVorazan, DeepL
- 한국어 번역: [Tea Barley](https://www.youtube.com/@teabarley), [Srty7462](https://www.youtube.com/@srty7462), [Sepheille](https://www.youtube.com/@cinitalp)
- [이전 버그 추적기](https://github.com/ack7139/thprac/issues)의 모든 보고서를 [이곳](https://github.com/touhouworldcup/thprac/issues)으로 이전: [toimine](https://www.youtube.com/channel/UCtxu8Rg0Vh8mX6iENenetuA)
- 영문 README.md: [Galagyy](https://github.com/Galagyy)
- 중문 README.md 번역: [TNT569](https://github.com/TNT569), [H-J-Granger](https://github.com/H-J-Granger)
- 일문 README.md 번역: [wefma](https://github.com/wefma)
- 국문 README.md 번역: [Tea Barley](https://www.youtube.com/@teabarley)

## <a name="building-from-source"></a> **소스에서 빌드하기**
### 최초 설정(한 번만 수행)
`thprac` 폴더 안에서 원하는 방법으로 `loc_json.cpp`를 컴파일하여 `loc_json.exe`를 만드세요. 다음 명령을 권장합니다.
```
cl /Isrc\3rdparties\yyjson /nologo /EHsc /O2 /std:c++20 loc_json.cpp .\src\3rdParties\yyjson\yyjson.c /Fe:loc_json.exe
```

### 명령줄에서 빌드하기
Visual Studio Developer Command Prompt에서 다음 명령을 실행하세요.
```
msbuild thprac.sln -t:restore,build -p:RestorePackagesConfig=true,Configuration=Release
```

### Visual Studio GUI에서 빌드하기
`thprac.sln`을 열고 "Build"를 클릭한 다음 "Build solution"을 클릭하세요.

## <a name="faq"></a> **자주 묻는 질문(FAQ)**

### 일반

#### thprac이 이전된 이유는 무엇인가요?
원 개발자인 Ack는 thprac/Marketeer의 향후 개발을 기한 없이 중단했습니다. 다음은 Ack의 입장문입니다.
> 저는 thprac/Marketeer의 향후 개발을 기한 없이 중단합니다. 라이선스 조건을 준수한다면 자유롭게 개발을 이어가셔도 됩니다.
> 제 실력이 부족하여 코드에 이해하기 어려운 작성 방식과 잘못된 로직이 가득하고, 전체가 엉망이 되었습니다. 이로 인해 불편을 드렸다면 죄송합니다.

현재 Ack에게 연락할 수 없으며, 다른 개발자들이 개발을 이어받았습니다.

#### 백신 프로그램에서 thprac을 악성 코드라고 합니다. 안전한가요?
thprac에는 악성 코드가 없지만, 동작 방식 때문에 백신 프로그램이 이를 감지할 수 있습니다. 감지된 경우 thprac이 작동할 수 있도록 백신 프로그램에 예외 또는 신뢰 규칙을 추가하세요. 또는 [이 버전](https://github.com/touhouworldcup/thprac/issues/112)을 사용해 보고 문제가 계속 발생하는지 알려주세요.

---

### 호환성

#### thprac은 영어 패치와 함께 작동하나요?
thprac은 **thcrap**과 호환되며 [Universal THCRAP Launcher](https://github.com/thpatch/Universal-THCRAP-Launcher/)처럼 thcrap 런처로 사용할 수 있습니다. gensokyo.org에서 만든 패치와 같은 정적 영어 패치는 지원하지 않습니다.

---

#### thprac이 Embodiment of Scarlet Devil을 찾지 못합니다. 어떻게 해야 하나요?

실행 파일 이름이 `東方紅魔郷.exe` 또는 `th06.exe`인지 확인하세요. 그래도 thprac이 감지하지 못하면 런처를 통해 이름에 상관없이 게임을 직접 실행하여 thprac을 게임에 연결할 수 있습니다.

---

### 기능

#### TH06-10에서 게임 도중 리플레이를 저장하려면 어떻게 해야 하나요?
기술적인 한계로 인해 게임 도중 리플레이 저장은 지원되지 않습니다. thprac 2.0.8.3 설명서의 내용은 다음과 같습니다.
> 이 게임들의 프로그래밍 방식 때문에 이 기능을 추가하기가 상당히 까다로워 현재는 직접적인 해결 방법이 없습니다.

하지만 이제 EoSD에서는 이 기능을 지원합니다.

참고: 게임 도중 저장한 리플레이는 저장 지점 이후에 타이틀 화면으로 돌아가지 않습니다.

---

#### "Everlasting BGM"은 무엇인가요?
이 옵션은 게임을 다시 시작할 때 배경 음악(BGM)이 처음부터 다시 재생되지 않게 합니다.

---

#### "Coercive Reporting"은 무엇인가요? (Shoot the Bullet/Double Spoiler)
이 기능은 카메라가 항상 보스를 향하도록 고정하고 카메라의 재충전 시간을 없앱니다.

---

#### 언어를 어떻게 변경하나요?
- 런처는 Windows 설정에 따라 언어를 자동으로 선택합니다.
- 게임 내 언어를 변경하려면 다음 단축키를 사용하세요.
  - **`ALT + 1`**: 일본어
  - **`ALT + 2`**: 중국어
  - **`ALT + 3`**: 영어
  - **`ALT + 4`**: 한국어

언어 변경 단축키는 런처의 설정 탭에서 변경할 수 있습니다.

이 단축키는 런처 자체에서는 작동하지 않습니다. 자세한 사용법은 **"사용법"** 섹션의 영상을 참고하세요.

---

### 버그 신고

#### 버그는 어디에 신고할 수 있나요?
버그를 신고하거나 개선 사항을 제안하려면 [GitHub Issues 탭](https://github.com/touhouworldcup/thprac/issues)을 방문하세요.

---

### 기술 문제

#### 고급 옵션에 Unsupported VsyncPatch 버전이 표시됩니다
호환되는 VsyncPatch 버전을 사용하고 있는지 확인하세요. [여기](https://maribelhearn.com/tools#vpatch)에서 다운로드할 수 있습니다. 가능하면 **rev7**의 DLL을 사용하세요.

---

#### vpatch를 사용할 때 FPS 조정이 제대로 작동하지 않는 것 같습니다

"DX8 to DX9 Converter"와 같은 일부 도구는 VsyncPatch와 충돌합니다. 리플레이 속도 조정(감속/가속)은 **TH13**에서만 지원됩니다.

---

### 게임별 항목

#### "DDC - Marisa Laser Related"는 무엇인가요?
이 옵션은 **Double Dealing Character(TH14)**의 악명 높은 Marisa 레이저 동기화 오류를 수정합니다. 원 개발자 Ack의 [Bilibili 시연 영상](https://www.bilibili.com/video/av285566068)(중국어, [YouTube 백업 영상](https://www.youtube.com/watch?v=Hkh_AEGHLto))을 참고하세요.
