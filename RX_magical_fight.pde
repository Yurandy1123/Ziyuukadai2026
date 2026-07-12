// ============================================================
// RX_magical_fight.pde  ★ 防御ミニゲーム担当 ★
//
// このファイルが担当するシーン
//
// scene == 5
//   敵攻撃の種類を表示
//   ENTERキーを押す
//   3秒カウントダウン
//
// scene == 6
//   クリック系防御
//   0 = Gridshot
//   1 = Sixshot
//
// scene == 7
//   追跡系防御
//   2 = Tracking
//   3 = Switch Track
//
// scene == 8
//   敵攻撃結果
//   ENTERキーでscene 0へ戻る
//
// 共有変数（Ziyuukadai2026.pdeで宣言済み）
//
// guardSuccess
// enemyAttackType
// timer
// player.hp
// enemy.attack
// message
// scene
//
// enemyAttackType
//   0 = Gridshot
//   1 = Sixshot
//   2 = Tracking
//   3 = Switch Track
// ============================================================


// ============================================================
// 共通変数
// ============================================================

// 防御スコア
int guardScore = 0;

// 防御ゲームの時間
// 300フレームで約5秒
int guardGameTime = 300;
int guardGameTimer = 300;

// 命中・ミス
int guardHitCount = 0;
int guardMissCount = 0;

// 敵攻撃結果でダメージを一度だけ与えるための変数
boolean enemyDamageApplied = false;

// 結果画面でENTERを待つ
boolean enemyResultWaiting = false;


// ============================================================
// 敵準備・カウントダウン用
// ============================================================

// false：攻撃内容の説明画面
// true ：カウントダウン中
boolean guardCountdownActive = false;

// 180フレームで3秒
int guardCountdownTimer = 180;


// ============================================================
// Gridshot用
// ============================================================

float gridX;
float gridY;

float gridR = 45;

int gridGoal = 15;


// ============================================================
// Sixshot用
// ============================================================

int sixTargetCount = 6;

float[] sixX = new float[sixTargetCount];
float[] sixY = new float[sixTargetCount];

float sixR = 18;


// ============================================================
// Tracking用
// ============================================================

float trackBallX;
float trackBallY;

float trackBallVX;
float trackBallVY;

float trackBallR = 40;

int trackInsideFrames = 0;


// ============================================================
// Switch Track用
// ============================================================

int switchTargetCount = 3;

float[] switchBallX = new float[switchTargetCount];
float[] switchBallY = new float[switchTargetCount];

float[] switchBallVX = new float[switchTargetCount];
float[] switchBallVY = new float[switchTargetCount];

float switchBallR = 38;

// 現在追うべきターゲット
int activeSwitchTarget = 0;

// 正しいターゲットを追えたフレーム数
int switchCorrectFrames = 0;

// 何フレームごとにターゲットを変更するか
int switchChangeInterval = 60;
int switchChangeTimer = 60;


// ============================================================
// scene 5を開始する処理
// 敵ターン開始時に呼び出す
// ============================================================

void startEnemyPrepare() {

  // 4種類からランダム選択
  enemyAttackType = int(random(4));

  guardSuccess = false;
  guardScore = 0;

  guardHitCount = 0;
  guardMissCount = 0;

  guardCountdownActive = false;
  guardCountdownTimer = 180;

  enemyDamageApplied = false;
  enemyResultWaiting = false;

  timer = 0;

  scene = 5;
}


// ============================================================
// scene 5：敵準備画面＋3秒カウントダウン
// ============================================================

void enemyPrepareScene() {

  camera();
  hint(DISABLE_DEPTH_TEST);
  background(30);

  // ---------------------------------------------
  // 攻撃内容を表示してENTER待ち
  // ---------------------------------------------

  if (!guardCountdownActive) {

    fill(255);
    textSize(32);
    text(
      "敵の攻撃が来る！",
      width / 2,
      height / 2 - 130
    );

    fill(255, 220, 0);
    textSize(32);
    text(
      getGuardGameName(),
      width / 2,
      height / 2 - 60
    );

    fill(255);
    textSize(22);
    text(
      getGuardInstruction(),
      width / 2,
      height / 2 + 10
    );

    fill(200);
    textSize(18);
    text(
      "防御スコアに応じて受けるダメージが変化します",
      width / 2,
      height / 2 + 70
    );

    fill(255, 220, 0);
    textSize(22);
    text(
      "ENTERキーでカウントダウン開始",
      width / 2,
      height / 2 + 140
    );

    return;
  }


  // ---------------------------------------------
  // 3秒カウントダウン
  // ---------------------------------------------

  guardCountdownTimer--;

  fill(255);
  textSize(28);
  text(
    getGuardGameName(),
    width / 2,
    height / 2 - 150
  );

  fill(200);
  textSize(22);
  text(
    "防御開始まで",
    width / 2,
    height / 2 - 90
  );

  int countNumber = ceil(
    guardCountdownTimer / 60.0
  );

  if (countNumber >= 1) {

    fill(255, 220, 0);
    textSize(120);

    text(
      countNumber,
      width / 2,
      height / 2 + 20
    );
  }

  // 最後の約0.25秒だけSTARTを表示
  if (guardCountdownTimer <= 15) {

    fill(0, 255, 150);
    textSize(65);

    text(
      "START!",
      width / 2,
      height / 2 + 20
    );
  }

  fill(180);
  textSize(18);
  text(
    "マウスを準備してください",
    width / 2,
    height / 2 + 150
  );

  if (guardCountdownTimer <= 0) {

    startSelectedGuardGame();
  }
}


// ============================================================
// 攻撃名を返す
// ============================================================

String getGuardGameName() {

  if (enemyAttackType == 0) {
    return "GRIDSHOT";
  }

  if (enemyAttackType == 1) {
    return "SIXSHOT";
  }

  if (enemyAttackType == 2) {
    return "TRACKING";
  }

  return "SWITCH TRACK";
}


// ============================================================
// 攻撃説明を返す
// ============================================================

String getGuardInstruction() {

  if (enemyAttackType == 0) {
    return "出現する大きな球を素早くクリック！";
  }

  if (enemyAttackType == 1) {
    return "6個の小さな球を正確にクリック！";
  }

  if (enemyAttackType == 2) {
    return "動く球をマウスで追い続けろ！";
  }

  return "緑色の球だけを追い続けろ！";
}


// ============================================================
// 選ばれた防御ゲームを開始
// ============================================================

void startSelectedGuardGame() {

  guardCountdownActive = false;

  if (enemyAttackType == 0) {

    startGridshot();

  } else if (enemyAttackType == 1) {

    startSixshot();

  } else if (enemyAttackType == 2) {

    startTrackingGuard();

  } else {

    startSwitchTrack();
  }
}


// ============================================================
// scene 6：クリック系防御
//
// enemyAttackType == 0
//   Gridshot
//
// enemyAttackType == 1
//   Sixshot
// ============================================================

void flickGuardScene() {

  if (enemyAttackType == 0) {

    gridshotScene();

  } else {

    sixshotScene();
  }
}


// ============================================================
// Gridshot開始
// ============================================================

void startGridshot() {

  guardGameTimer = guardGameTime;

  guardHitCount = 0;
  guardMissCount = 0;

  spawnGridTarget();

  scene = 6;
}


// ============================================================
// Gridshot描画
// ============================================================

void gridshotScene() {

  camera();
  hint(DISABLE_DEPTH_TEST);
  background(25, 10, 10);

  guardGameTimer--;

  drawClickGuardHeader(
    "GRIDSHOT",
    "大きな球を素早くクリック"
  );

  noStroke();

  fill(255, 70, 70);
  ellipse(
    gridX,
    gridY,
    gridR * 2,
    gridR * 2
  );

  fill(255, 180, 180);
  ellipse(
    gridX,
    gridY,
    gridR * 1.2,
    gridR * 1.2
  );

  fill(255);
  ellipse(
    gridX,
    gridY,
    gridR * 0.35,
    gridR * 0.35
  );

  drawCrosshair();

  if (guardGameTimer <= 0) {

    finishGridshot();
  }
}


// ============================================================
// Gridshotの球を出現
// ============================================================

void spawnGridTarget() {

  gridX = random(
    gridR + 50,
    width - gridR - 50
  );

  gridY = random(
    190,
    height - gridR - 40
  );
}


// ============================================================
// Gridshot終了
// ============================================================

void finishGridshot() {

  float accuracy = calculateGuardAccuracy();

  int speedScore = int(
    map(
      guardHitCount,
      0,
      gridGoal,
      0,
      70
    )
  );

  int accuracyScore = int(
    accuracy * 30
  );

  guardScore =
    speedScore +
    accuracyScore;

  guardScore = constrain(
    guardScore,
    0,
    100
  );

  finishGuardGame();
}


// ============================================================
// Sixshot開始
// ============================================================

void startSixshot() {

  guardGameTimer = guardGameTime;

  guardHitCount = 0;
  guardMissCount = 0;

  // 最初は画面外に置く
  for (int i = 0; i < sixTargetCount; i++) {

    sixX[i] = -1000;
    sixY[i] = -1000;
  }

  // 6個のターゲットを配置
  for (int i = 0; i < sixTargetCount; i++) {

    spawnSixTarget(i);
  }

  scene = 6;
}


// ============================================================
// Sixshot描画
// ============================================================

void sixshotScene() {

  camera();
  hint(DISABLE_DEPTH_TEST);
  background(10, 10, 28);

  guardGameTimer--;

  drawClickGuardHeader(
    "SIXSHOT",
    "小さな球を正確にクリック"
  );

  for (int i = 0; i < sixTargetCount; i++) {

    noStroke();

    fill(90, 140, 255);
    ellipse(
      sixX[i],
      sixY[i],
      sixR * 2,
      sixR * 2
    );

    fill(200, 220, 255);
    ellipse(
      sixX[i],
      sixY[i],
      sixR,
      sixR
    );

    fill(255);
    ellipse(
      sixX[i],
      sixY[i],
      5,
      5
    );
  }

  drawCrosshair();

  if (guardGameTimer <= 0) {

    finishSixshot();
  }
}


// ============================================================
// Sixshotの球を配置
// ============================================================

void spawnSixTarget(int index) {

  boolean validPosition = false;
  int attempts = 0;

  while (
    !validPosition &&
    attempts < 100
  ) {

    sixX[index] = random(
      60,
      width - 60
    );

    sixY[index] = random(
      190,
      height - 50
    );

    validPosition = true;

    for (int i = 0; i < sixTargetCount; i++) {

      if (i != index) {

        float d = dist(
          sixX[index],
          sixY[index],
          sixX[i],
          sixY[i]
        );

        if (d < 70) {

          validPosition = false;
        }
      }
    }

    attempts++;
  }
}


// ============================================================
// Sixshot終了
// ============================================================

void finishSixshot() {

  float accuracy = calculateGuardAccuracy();

  int speedScore = int(
    map(
      guardHitCount,
      0,
      18,
      0,
      60
    )
  );

  int accuracyScore = int(
    accuracy * 40
  );

  guardScore =
    speedScore +
    accuracyScore;

  guardScore = constrain(
    guardScore,
    0,
    100
  );

  finishGuardGame();
}


// ============================================================
// クリック系ゲーム共通ヘッダー
// ============================================================

void drawClickGuardHeader(
  String title,
  String instruction
) {

  fill(255);

  textSize(27);
  text(
    title,
    width / 2,
    30
  );

  textSize(17);
  text(
    instruction,
    width / 2,
    65
  );

  text(
    "命中 : " +
    guardHitCount +
    "　ミス : " +
    guardMissCount,
    width / 2,
    95
  );

  int totalShots =
    guardHitCount +
    guardMissCount;

  int accuracyPercent = 100;

  if (totalShots > 0) {

    accuracyPercent = int(
      100.0 *
      guardHitCount /
      totalShots
    );
  }

  text(
    "命中率 : " +
    accuracyPercent +
    "%",
    width / 2,
    125
  );

  text(
    "残り時間 : " +
    formatGuardTime(guardGameTimer),
    width / 2,
    155
  );

  drawGuardTimeBar();
}


// ============================================================
// scene 6でのマウス処理
//
// Ziyuukadai2026.pdeのmousePressedから呼び出す
// ============================================================

void flickMousePressed() {

  if (scene != 6) {
    return;
  }

  if (enemyAttackType == 0) {

    gridshotMousePressed();

  } else if (enemyAttackType == 1) {

    sixshotMousePressed();
  }
}


// ============================================================
// Gridshotクリック処理
// ============================================================

void gridshotMousePressed() {

  float d = dist(
    mouseX,
    mouseY,
    gridX,
    gridY
  );

  if (d <= gridR) {

    guardHitCount++;

    spawnGridTarget();

  } else {

    guardMissCount++;
  }
}


// ============================================================
// Sixshotクリック処理
// ============================================================

void sixshotMousePressed() {

  int clickedTarget = -1;

  for (int i = 0; i < sixTargetCount; i++) {

    float d = dist(
      mouseX,
      mouseY,
      sixX[i],
      sixY[i]
    );

    if (d <= sixR) {

      clickedTarget = i;
      break;
    }
  }

  if (clickedTarget >= 0) {

    guardHitCount++;

    spawnSixTarget(clickedTarget);

  } else {

    guardMissCount++;
  }
}


// ============================================================
// scene 7：追跡系防御
//
// enemyAttackType == 2
//   Tracking
//
// enemyAttackType == 3
//   Switch Track
// ============================================================

void trackingGuardScene() {

  if (enemyAttackType == 2) {

    normalTrackingScene();

  } else {

    switchTrackScene();
  }
}


// ============================================================
// Tracking開始
// ============================================================

void startTrackingGuard() {

  guardGameTimer = guardGameTime;

  trackBallX = width / 2;
  trackBallY = height / 2;

  trackBallVX = randomGuardSpeed(
    3.0,
    5.0
  );

  trackBallVY = randomGuardSpeed(
    3.0,
    5.0
  );

  trackInsideFrames = 0;

  scene = 7;
}


// ============================================================
// Tracking描画
// ============================================================

void normalTrackingScene() {

  camera();
  hint(DISABLE_DEPTH_TEST);
  background(0, 20, 20);

  guardGameTimer--;

  updateTrackingBall();

  float d = dist(
    mouseX,
    mouseY,
    trackBallX,
    trackBallY
  );

  if (d <= trackBallR) {

    trackInsideFrames++;
  }

  int currentScore = int(
    map(
      trackInsideFrames,
      0,
      guardGameTime,
      0,
      100
    )
  );

  currentScore = constrain(
    currentScore,
    0,
    100
  );

  fill(255);

  textSize(27);
  text(
    "TRACKING",
    width / 2,
    35
  );

  textSize(18);
  text(
    "動く球を追い続けろ",
    width / 2,
    75
  );

  text(
    "追跡率 : " +
    currentScore +
    "%",
    width / 2,
    110
  );

  text(
    "残り時間 : " +
    formatGuardTime(guardGameTimer),
    width / 2,
    145
  );

  drawGuardTimeBar();

  noStroke();

  if (d <= trackBallR) {

    fill(0, 255, 150);

  } else {

    fill(255, 80, 80);
  }

  ellipse(
    trackBallX,
    trackBallY,
    trackBallR * 2,
    trackBallR * 2
  );

  fill(255, 160);
  ellipse(
    trackBallX,
    trackBallY,
    trackBallR,
    trackBallR
  );

  drawCrosshair();

  if (guardGameTimer <= 0) {

    guardScore = int(
      map(
        trackInsideFrames,
        0,
        guardGameTime,
        0,
        100
      )
    );

    guardScore = constrain(
      guardScore,
      0,
      100
    );

    finishGuardGame();
  }
}


// ============================================================
// Trackingの球を動かす
// ============================================================

void updateTrackingBall() {

  trackBallX += trackBallVX;
  trackBallY += trackBallVY;

  if (
    trackBallX <= trackBallR ||
    trackBallX >= width - trackBallR
  ) {

    trackBallVX *= -1;

    trackBallX = constrain(
      trackBallX,
      trackBallR,
      width - trackBallR
    );
  }

  if (
    trackBallY <= 190 ||
    trackBallY >= height - trackBallR
  ) {

    trackBallVY *= -1;

    trackBallY = constrain(
      trackBallY,
      190,
      height - trackBallR
    );
  }

  // 一定時間ごとに少し動きを変化させる
  if (frameCount % 45 == 0) {

    trackBallVX += random(-1.2, 1.2);
    trackBallVY += random(-1.2, 1.2);

    trackBallVX = limitGuardSpeed(
      trackBallVX,
      2.5,
      6.0
    );

    trackBallVY = limitGuardSpeed(
      trackBallVY,
      2.5,
      6.0
    );
  }
}


// ============================================================
// Switch Track開始
// ============================================================

void startSwitchTrack() {

  guardGameTimer = guardGameTime;

  switchCorrectFrames = 0;

  activeSwitchTarget = int(
    random(switchTargetCount)
  );

  switchChangeTimer =
    switchChangeInterval;

  for (int i = 0; i < switchTargetCount; i++) {

    switchBallX[i] = random(
      100,
      width - 100
    );

    switchBallY[i] = random(
      210,
      height - 80
    );

    switchBallVX[i] = randomGuardSpeed(
      2.0,
      4.0
    );

    switchBallVY[i] = randomGuardSpeed(
      2.0,
      4.0
    );
  }

  scene = 7;
}


// ============================================================
// Switch Track描画
// ============================================================

void switchTrackScene() {

  camera();
  hint(DISABLE_DEPTH_TEST);
  background(20, 12, 28);

  guardGameTimer--;
  switchChangeTimer--;

  updateSwitchBalls();

  if (switchChangeTimer <= 0) {

    changeSwitchTarget();
  }

  float activeDistance = dist(
    mouseX,
    mouseY,
    switchBallX[activeSwitchTarget],
    switchBallY[activeSwitchTarget]
  );

  if (activeDistance <= switchBallR) {

    switchCorrectFrames++;
  }

  int currentScore = int(
    map(
      switchCorrectFrames,
      0,
      guardGameTime,
      0,
      100
    )
  );

  currentScore = constrain(
    currentScore,
    0,
    100
  );

  fill(255);

  textSize(27);
  text(
    "SWITCH TRACK",
    width / 2,
    35
  );

  textSize(18);
  text(
    "緑色の球だけを追い続けろ",
    width / 2,
    70
  );

  text(
    "追跡率 : " +
    currentScore +
    "%",
    width / 2,
    105
  );

  text(
    "ターゲット変更まで : " +
    nf(
      switchChangeTimer / 60.0,
      1,
      1
    ) +
    "秒",
    width / 2,
    135
  );

  text(
    "残り時間 : " +
    formatGuardTime(guardGameTimer),
    width / 2,
    165
  );

  drawGuardTimeBar();

  for (int i = 0; i < switchTargetCount; i++) {

    noStroke();

    if (i == activeSwitchTarget) {

      if (activeDistance <= switchBallR) {

        fill(0, 255, 150);

      } else {

        fill(70, 220, 110);
      }

    } else {

      fill(140, 60, 180);
    }

    ellipse(
      switchBallX[i],
      switchBallY[i],
      switchBallR * 2,
      switchBallR * 2
    );

    fill(255, 100);
    ellipse(
      switchBallX[i],
      switchBallY[i],
      switchBallR,
      switchBallR
    );

    if (i == activeSwitchTarget) {

      fill(255);
      textSize(15);

      text(
        "TARGET",
        switchBallX[i],
        switchBallY[i] -
        switchBallR -
        17
      );
    }
  }

  drawCrosshair();

  if (guardGameTimer <= 0) {

    guardScore = int(
      map(
        switchCorrectFrames,
        0,
        guardGameTime,
        0,
        100
      )
    );

    guardScore = constrain(
      guardScore,
      0,
      100
    );

    finishGuardGame();
  }
}


// ============================================================
// Switch Trackの球を移動
// ============================================================

void updateSwitchBalls() {

  for (int i = 0; i < switchTargetCount; i++) {

    switchBallX[i] += switchBallVX[i];
    switchBallY[i] += switchBallVY[i];

    if (
      switchBallX[i] <= switchBallR ||
      switchBallX[i] >= width - switchBallR
    ) {

      switchBallVX[i] *= -1;

      switchBallX[i] = constrain(
        switchBallX[i],
        switchBallR,
        width - switchBallR
      );
    }

    if (
      switchBallY[i] <= 190 ||
      switchBallY[i] >= height - switchBallR
    ) {

      switchBallVY[i] *= -1;

      switchBallY[i] = constrain(
        switchBallY[i],
        190,
        height - switchBallR
      );
    }
  }
}


// ============================================================
// Switch Trackの対象変更
// ============================================================

void changeSwitchTarget() {

  int oldTarget =
    activeSwitchTarget;

  while (
    activeSwitchTarget ==
    oldTarget
  ) {

    activeSwitchTarget = int(
      random(switchTargetCount)
    );
  }

  switchChangeTimer =
    switchChangeInterval;
}


// ============================================================
// 防御ゲーム終了
// ============================================================

void finishGuardGame() {

  guardScore = constrain(
    guardScore,
    0,
    100
  );

  guardSuccess =
    guardScore >= 70;

  enemyDamageApplied = false;
  enemyResultWaiting = true;

  timer = 0;

  scene = 8;
}


// ============================================================
// scene 8：敵攻撃結果
// ============================================================

void enemyResultScene() {

  camera();
  hint(DISABLE_DEPTH_TEST);
  background(30, 0, 0);

  int damage;

  // 防御スコアによって受けるダメージを変更
  if (guardScore >= 90) {

    damage = max(
      1,
      enemy.attack / 6
    );

  } else if (guardScore >= 70) {

    damage = max(
      1,
      enemy.attack / 3
    );

  } else if (guardScore >= 50) {

    damage = max(
      1,
      enemy.attack / 2
    );

  } else if (guardScore >= 30) {

    damage = max(
      1,
      int(enemy.attack * 0.75)
    );

  } else {

    damage = enemy.attack;
  }

  // ダメージを一度だけ適用
  if (!enemyDamageApplied) {

    player.hp -= damage;

    if (player.hp < 0) {
      player.hp = 0;
    }

    message =
      message +
      "  /  敵の攻撃 " +
      damage +
      "ダメージ";

    enemyDamageApplied = true;
  }

  fill(255);
  textSize(32);
  text(
    "敵の攻撃！",
    width / 2,
    height / 2 - 170
  );

  fill(200);
  textSize(20);
  text(
    "防御種目：" +
    getGuardGameName(),
    width / 2,
    height / 2 - 125
  );

  textSize(28);

  if (guardScore >= 90) {

    fill(255, 220, 0);
    text(
      "PERFECT!",
      width / 2,
      height / 2 - 75
    );

  } else if (guardScore >= 70) {

    fill(0, 255, 150);
    text(
      "防御成功！",
      width / 2,
      height / 2 - 75
    );

  } else if (guardScore >= 50) {

    fill(120, 190, 255);
    text(
      "少し防御できた！",
      width / 2,
      height / 2 - 75
    );

  } else if (guardScore >= 30) {

    fill(255, 160, 80);
    text(
      "防御が足りない！",
      width / 2,
      height / 2 - 75
    );

  } else {

    fill(255, 80, 80);
    text(
      "防御失敗！",
      width / 2,
      height / 2 - 75
    );
  }

  fill(255);
  textSize(22);

  text(
    "防御スコア：" +
    guardScore,
    width / 2,
    height / 2 - 25
  );

  text(
    "受けたダメージ：" +
    damage,
    width / 2,
    height / 2 + 15
  );

  text(
    "現在のHP：" +
    player.hp,
    width / 2,
    height / 2 + 55
  );

  // 攻撃エフェクト
  noStroke();

  fill(180, 0, 255, 180);
  ellipse(
    width / 4,
    height / 2 + 100,
    220,
    220
  );

  fill(255, 120, 255, 160);
  ellipse(
    width / 4,
    height / 2 + 100,
    100,
    100
  );

  fill(255, 220, 0);
  textSize(20);

  text(
    "ENTERキーで戦闘メニューへ",
    width / 2,
    height - 55
  );
}


// ============================================================
// ENTERキー処理
//
// Ziyuukadai2026.pdeのkeyPressedから呼び出す
// ============================================================

void magicalFightKeyPressed() {

  // scene 5：説明画面からカウントダウンへ
  if (scene == 5) {

    if (
      keyCode == ENTER &&
      !guardCountdownActive
    ) {

      guardCountdownActive = true;
      guardCountdownTimer = 180;
    }
  }

  // scene 8：結果画面から戦闘メニューへ
  else if (scene == 8) {

    if (
      keyCode == ENTER &&
      enemyResultWaiting
    ) {

      guardSuccess = false;
      guardScore = 0;

      enemyDamageApplied = false;
      enemyResultWaiting = false;

      timer = 0;

      scene = 0;
    }
  }
}


// ============================================================
// 命中率計算
// ============================================================

float calculateGuardAccuracy() {

  int total =
    guardHitCount +
    guardMissCount;

  if (total == 0) {

    return 0;
  }

  return guardHitCount /
    float(total);
}


// ============================================================
// 時間表示
// ============================================================

String formatGuardTime(int frames) {

  float seconds =
    max(0, frames) / 60.0;

  return nf(
    seconds,
    1,
    1
  ) + "秒";
}


// ============================================================
// 時間バー
// ============================================================

void drawGuardTimeBar() {

  float barWidth = 400;

  float ratio =
    guardGameTimer /
    float(guardGameTime);

  ratio = constrain(
    ratio,
    0,
    1
  );

  noStroke();

  fill(70);
  rect(
    width / 2 - barWidth / 2,
    175,
    barWidth,
    12
  );

  fill(255);
  rect(
    width / 2 - barWidth / 2,
    175,
    barWidth * ratio,
    12
  );
}


// ============================================================
// ランダムな移動速度
// ============================================================

float randomGuardSpeed(
  float minimum,
  float maximum
) {

  float speed = random(
    minimum,
    maximum
  );

  if (random(1) < 0.5) {

    speed *= -1;
  }

  return speed;
}


// ============================================================
// 移動速度を制限
// ============================================================

float limitGuardSpeed(
  float speed,
  float minimum,
  float maximum
) {

  float direction = 1;

  if (speed < 0) {

    direction = -1;
  }

  float absoluteSpeed =
    abs(speed);

  absoluteSpeed = constrain(
    absoluteSpeed,
    minimum,
    maximum
  );

  return absoluteSpeed *
    direction;
}


// ============================================================
// クロスヘア描画
// ============================================================

void drawCrosshair() {

  stroke(255);
  strokeWeight(2);

  line(
    mouseX - 15,
    mouseY,
    mouseX + 15,
    mouseY
  );

  line(
    mouseX,
    mouseY - 15,
    mouseX,
    mouseY + 15
  );

  noFill();

  ellipse(
    mouseX,
    mouseY,
    8,
    8
  );

  noStroke();
}
