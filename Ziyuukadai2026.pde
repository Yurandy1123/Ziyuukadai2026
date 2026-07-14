// ============================================================
// Ziyuukadai2026.pde  ★ メインファイル ★
//
// シーン番号一覧
//   0 : 戦闘メニュー（このファイル）
//   1 : 魔法陣       （KONOdemo_v1.pde）
//   2 : AR道具       （Tool.pde）
//   3 : 勝利         （このファイル）
//   4 : 敗北         （このファイル）
//   5 : 敵準備       （RX_magical_fight.pde）
//   6 : フリック防御 （RX_magical_fight.pde）
//   7 : トラッキング （RX_magical_fight.pde）
//   8 : 敵攻撃結果   （RX_magical_fight.pde）
// ============================================================

import processing.video.*;
import gab.opencv.*;
import jp.nyatla.nyar4psg.*;
import java.awt.Rectangle;

// =============================================
// 共有オブジェクト
// =============================================
Player player;
Enemy  enemy;
PFont  font;

Capture   video;
OpenCV    opencv;
MultiMarker nya;

PShape[] itemModel = new PShape[3];

// =============================================
// 共有変数
// =============================================
int     scene      = 0;
String  message    = "";
boolean playerTurn = true;
int     timer      = 0;

int prevScene = -1;

boolean guardSuccess    = false;
int     enemyAttackType = 0;

int     magicDamage   = 0;
boolean magicFinished = false;

boolean itemFinished = false;

// =============================================
// バトルステージ管理（バトル2・3/ボス用）
// =============================================
int    battleStage  = 1;      // 1:スライム 2:ゴブリン 3:ボス
String enemyName     = "スライム";

int commandCursor = 0;   // 0:たたかう 1:どうぐ 2:にげる

int blinkTimer = 0;

// ダメージ演出→敵ターンへの移行を少し待つための変数
boolean waitingPostDamage = false;
int     postDamageTimer   = 0;

// =============================================
// ダメージポップアップ演出
// =============================================
class DamagePopup {
  float x, y;
  String label;
  color col;
  int life;
}
ArrayList<DamagePopup> popups = new ArrayList<DamagePopup>();

void spawnDamagePopup(float x, float y, String label, color col) {
  DamagePopup p = new DamagePopup();
  p.x = x; p.y = y; p.label = label; p.col = col; p.life = 0;
  popups.add(p);
}

void updateAndDrawPopups() {
  for (int i = popups.size() - 1; i >= 0; i--) {
    DamagePopup p = popups.get(i);
    p.life++;
    float t = p.life / 50.0;
    if (t > 1) { popups.remove(i); continue; }

    float yOff = -t * 55;
    float a    = 255 * (1 - t);

    fill(red(p.col), green(p.col), blue(p.col), a);
    stroke(0, a);
    strokeWeight(2);
    textAlign(CENTER, CENTER);
    textSize(30);
    text(p.label, p.x, p.y + yOff);
    noStroke();
  }
}

// =============================================
// setup
// =============================================
void setup() {
  size(640, 480, P3D);
  hint(DISABLE_DEPTH_TEST);

  font = createFont("Meiryo", 24, true);
  textFont(font);
  textAlign(CENTER, CENTER);

  player = new Player(100, 50, 20);
  enemy  = new Enemy(120, 15);
  enemyName = "スライム";
  message = "スライムが あらわれた！\nたたかえ！";

  String[] cameras = Capture.list();
  if (cameras != null && cameras.length > 0) {
    video  = new Capture(this, cameras[0]);
    video.start();
    opencv = new OpenCV(this, 640, 480);
  } else {
    println("カメラが見つかりません");
  }

  try {
    nya = new MultiMarker(this, width, height,
                          "camera_para.dat",
                          NyAR4PsgConfig.CONFIG_PSG);
    nya.addNyIdMarker(0, 40);
    nya.addNyIdMarker(1, 40);
    nya.addNyIdMarker(2, 40);
    itemModel[0] = loadShape("herb.obj");
    itemModel[1] = loadShape("bomb.obj");
    itemModel[2] = loadShape("seed.obj");
  } catch (Exception e) {
    println("AR初期化エラー: " + e.getMessage());
    println("camera_para.dat / *.obj を data/ フォルダに入れてください");
  }

  initMagic();
}

// =============================================
// draw
// =============================================
void draw() {
  if (video != null && video.available()) {
    video.read();
  }

  if (scene == 0 && prevScene != 0) {
    playerTurn = true;
  }
  prevScene = scene;

  blinkTimer++;

  // ---- ダメージ演出のための一時停止処理 ----
  if (waitingPostDamage) {
    postDamageTimer--;
    if (postDamageTimer <= 0) {
      waitingPostDamage = false;
      startEnemyDefense();
    }
  }

  switch (scene) {
    case 0: battleScene();        break;
    case 1: magicDrawScene();     break;
    case 2: itemARScene();        break;
    case 3: winScene();           break;
    case 4: loseScene();          break;
    case 5: enemyPrepareScene();  break;
    case 6: flickGuardScene();    break;
    case 7: trackingGuardScene(); break;
    case 8: enemyResultScene();   break;
  }

  checkMagicResult();
  checkItemResult();
  checkGameEnd();
}

// =============================================
// 戦闘メニュー画面（ドラクエ風）
// =============================================
void battleScene() {
  camera();
  ortho();
  hint(DISABLE_DEPTH_TEST);

  // ---- 背景（ボス戦は不穏な色に）----
  color topCol, botCol, groundCol;
  if (battleStage == 3) {
    topCol = color(70, 10, 20);
    botCol = color(140, 40, 60);
    groundCol = color(40, 20, 25);
  } else {
    topCol = color(70, 110, 200);
    botCol = color(150, 190, 240);
    groundCol = color(60, 140, 70);
  }

  for (int y = 0; y < height - 120; y++) {
    float t = y / float(height - 120);
    fill(lerpColor(topCol, botCol, t));
    noStroke();
    rect(0, y, width, 1);
  }
  fill(groundCol);
  rect(0, height - 120, width, 120);

  // ---- 敵描画 ----
  drawSlime(width / 2, 190);

  // ---- ダメージポップアップ ----
  updateAndDrawPopups();

  // ---- 敵名ウィンドウ ----
  drawDQWindow(width/2 - 90, 15, 180, 40);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(20);
  text(enemyName, width/2, 35);

  // ---- プレイヤーステータスウィンドウ ----
  drawDQWindow(15, 15, 190, 95);
  textAlign(LEFT, CENTER);
  textSize(18);
  fill(255, 230, 120);
  text("ゆうしゃ", 30, 35);
  fill(255);
  textSize(17);
  text("HP  " + player.hp + " / 100", 30, 62);
  text("MP  " + player.mp + " / 50",  30, 86);

  // ---- メッセージウィンドウ ----
  float msgX = 195;
  float msgW = width - 15 - msgX;

  drawDQWindow(msgX, height - 165, msgW, 150);
  fill(255);
  textAlign(LEFT, TOP);
  textSize(17);
  text(message, msgX + 20, height - 145, msgW - 40, 120);

  if ((blinkTimer / 25) % 2 == 0) {
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(16);
    text("▼", width - 45, height - 35);
  }

  // ---- コマンドウィンドウ（たたかう／どうぐ／にげる）----
  drawDQWindow(15, height - 165, 170, 150);
  textAlign(LEFT, CENTER);
  textSize(19);

  String[] commands = {"たたかう", "どうぐ", "にげる"};
  boolean canAct = playerTurn && !waitingPostDamage;

  for (int i = 0; i < commands.length; i++) {
    float cy = height - 130 + i * 40;

    if (canAct && i == commandCursor) {
      fill(255, 230, 120);
      text("▶", 30, cy);
    }
    fill(canAct ? color(255) : color(150));
    text(commands[i], 55, cy);
  }

  if (!canAct) {
    fill(0, 140);
    noStroke();
    rect(15, height - 165, 170, 150, 10);
    fill(255, 120, 120);
    textAlign(CENTER, CENTER);
    textSize(18);
    text("てきの\nターン", 15 + 85, height - 90);
  }

  textAlign(CENTER, CENTER);
}

// ---- ドラクエ風ウィンドウ枠 ----
void drawDQWindow(float x, float y, float w, float h) {
  noStroke();
  fill(10, 20, 90);
  rect(x, y, w, h, 6);

  noFill();
  stroke(255);
  strokeWeight(3);
  rect(x + 4, y + 4, w - 8, h - 8, 4);
  strokeWeight(1);
  rect(x + 8, y + 8, w - 16, h - 16, 3);
  noStroke();
}

// =============================================
// 勝利・敗北
// =============================================
void winScene() {
  camera();
  ortho();
  background(20, 20, 70);

  fill(255, 230, 120);
  textSize(46);
  textAlign(CENTER, CENTER);

  if (battleStage < 3) {
    text(enemyName + "を たおした！", width/2, height/2 - 60);
    fill(255);
    textSize(22);
    text("つぎの てきが あらわれる…", width/2, height/2 + 10);
    textSize(18);
    text("ENTERキーで つぎのバトルへ", width/2, height/2 + 60);
  } else {
    text("ボスを たおした！", width/2, height/2 - 30);
    fill(255);
    textSize(22);
    text("YOU WIN!", width/2, height/2 + 30);
  }
}

void loseScene() {
  camera();
  ortho();
  background(90, 10, 10);
  fill(255);
  textSize(60);
  textAlign(CENTER, CENTER);
  text("GAME OVER", width/2, height/2);
}

// =============================================
// 次のバトルへ（勝利画面でENTER）
// =============================================
void advanceStage() {
  battleStage++;

  if (battleStage == 2) {
    enemyName = "ゴブリン";
    enemy     = new Enemy(150, 22);
  } else if (battleStage == 3) {
    enemyName = "ボス";
    enemy     = new Enemy(220, 30);
  }

  message      = enemyName + "が あらわれた！\nたたかえ！";
  playerTurn   = true;
  commandCursor = 0;

  scene = 0;
}

// =============================================
// にげる処理
// =============================================
void attemptEscape() {
  if (random(1) < 0.5) {
    message = "うまく にげきれた！";
    // 成功：ターンは変わらず、そのまま自分のターンを継続
  } else {
    message = "にげられなかった！";
    playerTurn = false;
    startEnemyDefense();
  }
}

// =============================================
// 魔法陣の結果を受け取る
// =============================================
void checkMagicResult() {
  if (magicFinished) {
    enemy.hp   -= magicDamage;
    message     = "まほう せいこう！ " + magicDamage + " ダメージ";
    magicFinished = false;
    playerTurn  = false;

    spawnDamagePopup(width/2, 130, "-" + magicDamage, color(255, 80, 80));

    waitingPostDamage = true;
    postDamageTimer   = 45;
  }
}

// 道具の結果を受け取る
void checkItemResult() {
  if (itemFinished) {
    itemFinished = false;
    playerTurn   = false;

    waitingPostDamage = true;
    postDamageTimer   = 45;
  }
}

// 防御ミニゲームへ移行
void startEnemyDefense() {
  startEnemyPrepare();
}

// 勝敗判定
void checkGameEnd() {
  if (scene == 3 || scene == 4) return;
  if (enemy.hp  <= 0) scene = 3;
  if (player.hp <= 0) scene = 4;
}

// =============================================
// アイテム使用関数（Tool.pde から呼ばれる）
// =============================================
void useHealItem() {
  player.hp = min(player.hp + 30, 100);
  message   = "HPが 30 かいふくした！";
  spawnDamagePopup(105, 40, "+30", color(80, 255, 120));
  itemFinished = true;
}

void usePowerItem() {
  player.attack += 10;
  message = "こうげきりょくが あがった！";
  spawnDamagePopup(105, 40, "UP!", color(255, 220, 80));
  itemFinished = true;
}

void useBombItem() {
  enemy.hp -= 20;
  message  = enemyName + "に 20の ダメージ！";
  spawnDamagePopup(width/2, 130, "-20", color(255, 80, 80));
  itemFinished = true;
}

// =============================================
// 入力処理
// =============================================
void mousePressed() {

  if (scene == 0 && playerTurn && !waitingPostDamage) {
    if (mouseX > 15 && mouseX < 185) {
      int row = -1;
      if (mouseY > height - 150 && mouseY < height - 110) row = 0;
      else if (mouseY > height - 110 && mouseY < height - 70) row = 1;
      else if (mouseY > height - 70  && mouseY < height - 30) row = 2;

      if (row == 0) {
        commandCursor = 0;
        scene = 1;              // たたかう→魔法陣
      } else if (row == 1) {
        commandCursor = 1;
        scene = 2;              // どうぐ
      } else if (row == 2) {
        commandCursor = 2;
        attemptEscape();        // にげる
      }
    }
  }
  else if (scene == 1) {
    magicMousePressed();
  }
  else if (scene == 6) {
    flickMousePressed();
  }
}

void keyPressed() {
  if (keyCode == ESC) {
    key = 0;
    if (scene == 1 || scene == 2) {
      scene = 0;
    }
    return;
  }

  if (scene == 0 && playerTurn && !waitingPostDamage) {
    if (keyCode == UP) {
      commandCursor = (commandCursor + 2) % 3;
    }
    if (keyCode == DOWN) {
      commandCursor = (commandCursor + 1) % 3;
    }
    if (key == ENTER || key == RETURN) {
      if (commandCursor == 0) scene = 1;
      else if (commandCursor == 1) scene = 2;
      else attemptEscape();
    }
  }

  if (scene == 3 && battleStage < 3) {
    if (key == ENTER || key == RETURN) {
      advanceStage();
    }
  }

  if (scene == 1) {
    magicKeyPressed();
  }

  if (scene == 5 || scene == 8) {
    magicalFightKeyPressed();
  }

  if (scene == 2) {
    itemKeyPressed();
  }
}

// =============================================
// Player / Enemy クラス
// =============================================
class Player {
  int hp, mp, attack;
  Player(int hp, int mp, int attack) {
    this.hp     = hp;
    this.mp     = mp;
    this.attack = attack;
  }
}

// =============================================
// 敵の描画
// =============================================
void drawSlime(float x, float y) {
  pushMatrix();

  float bounce   = abs(sin(frameCount * 0.05));
  float hop      = bounce * 25;
  float squashX  = 1.0 + bounce * 0.18;
  float squashY  = 1.0 - bounce * 0.15;
  float stretchY = lerp(squashY, 1.15, bounce);
  float stretchX = lerp(squashX, 0.9,  bounce);

  if (battleStage == 3) {
    // ---- ボスは脈動する不気味な動き ----
    float pulse = 1.0 + sin(frameCount * 0.08) * 0.12;
    translate(x, y);
    scale(pulse, pulse);
    noStroke();

    fill(0, 60);
    ellipse(0, 90, 140, 24);

    fill(90, 10, 40);
    beginShape();
    for (int i = 0; i < 12; i++) {
      float ang = map(i, 0, 12, 0, TWO_PI);
      float r = 90 + sin(ang * 3 + frameCount * 0.1) * 12;
      vertex(cos(ang) * r, sin(ang) * r * 0.85 - 10);
    }
    endShape(CLOSE);

    fill(255, 60, 60);
    ellipse(-25, -20, 26, 30);
    ellipse(25, -20, 26, 30);
    fill(0);
    ellipse(-25, -18, 10, 14);
    ellipse(25, -18, 10, 14);

    noFill();
    stroke(255, 200, 0);
    strokeWeight(3);
    arc(0, 30, 45, 20, PI, TWO_PI);
    noStroke();

    popMatrix();
    return;
  }

  translate(x, y - hop);
  scale(stretchX, stretchY);
  noStroke();

  if (battleStage == 1) {
    pushMatrix();
    scale(1.0/stretchX, 1.0/stretchY);
    fill(0, 70 * (1.0 - bounce * 0.6));
    ellipse(0, 55 + hop, 90 * (1.0 - bounce*0.3), 18 * (1.0 - bounce*0.3));
    popMatrix();

    fill(70, 170, 255);
    beginShape();
    vertex(0, -70);
    bezierVertex(-55, -35, -60, 20, -40, 50);
    bezierVertex(-15, 80, 15, 80, 40, 50);
    bezierVertex(60, 20, 55, -35, 0, -70);
    endShape(CLOSE);

    fill(255, 180);
    ellipse(-18, -28, 18, 18);

    fill(255);
    ellipse(-15, -5, 18, 22);
    ellipse(15, -5, 18, 22);

    fill(0);
    ellipse(-15, 0, 6, 10);
    ellipse(15, 0, 6, 10);

    noFill();
    stroke(0);
    strokeWeight(3);
    arc(0, 25, 35, 15, 0, PI);
  } else {
    fill(90, 160, 70);
    ellipse(0, -10, 90, 100);

    fill(70, 130, 55);
    rect(-45, 30, 90, 60, 10);

    fill(255);
    ellipse(-20, -20, 22, 26);
    ellipse(20, -20, 22, 26);
    fill(200, 30, 30);
    ellipse(-20, -18, 8, 12);
    ellipse(20, -18, 8, 12);

    stroke(50, 90, 40);
    strokeWeight(3);
    noFill();
    arc(0, 15, 40, 20, 0, PI);
    noStroke();

    fill(255);
    triangle(-8, 20, -3, 20, -6, 30);
    triangle(8, 20, 3, 20, 6, 30);
  }

  popMatrix();
}

void drawButton(float x, float y, float w, float h, String s) {
  fill(45, 90, 220);
  stroke(255);
  strokeWeight(4);
  rect(x, y, w, h, 12);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(22);
  text(s, x + w/2, y + h/2);
}

class Enemy {
  int hp, attack;
  Enemy(int hp, int attack) {
    this.hp     = hp;
    this.attack = attack;
  }
}
