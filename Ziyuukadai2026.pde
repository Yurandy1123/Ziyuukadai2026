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

// カメラ（魔法陣・AR道具で共有）
Capture   video;
OpenCV    opencv;
MultiMarker nya;

// ARモデル（Tool.pde で使用）
PShape[] itemModel = new PShape[3];

// =============================================
// 共有変数
// =============================================
int     scene      = 0;
String  message    = "";
boolean playerTurn = true;
int     timer      = 0;

// 防御ミニゲームの結果（RX_magical_fight.pde で使用）
boolean guardSuccess    = false;
int     enemyAttackType = 0;   // 0:フリック  1:トラッキング

// 魔法陣との連携（KONOdemo_v1.pde → このファイル）
int     magicDamage   = 0;
boolean magicFinished = false;

// 道具との連携（Tool.pde → このファイル）
boolean itemFinished = false;

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

  // ---- カメラ初期化 ----
  String[] cameras = Capture.list();
  if (cameras != null && cameras.length > 0) {
    // 複数カメラがある場合は cameras[0] を変更してください
    video  = new Capture(this, cameras[0]);
    video.start();
    opencv = new OpenCV(this, 640, 480);
  } else {
    println("カメラが見つかりません");
  }

  // ---- 魔法陣の初期化（KONOdemo_v1.pde の関数）----
  initMagic();
}

// =============================================
// draw
// =============================================
void draw() {
  // カメラフレーム更新（scene 1・2 で使用）
  if (video != null && video.available()) {
    video.read();
  }

  switch (scene) {
    case 0: battleScene();        break;
    case 1: magicDrawScene();     break;   // KONOdemo_v1.pde
    case 2: itemARScene();        break;   // Tool.pde
    case 3: winScene();           break;
    case 4: loseScene();          break;
    case 5: enemyPrepareScene();  break;   // RX_magical_fight.pde
    case 6: flickGuardScene();    break;   // RX_magical_fight.pde
    case 7: trackingGuardScene(); break;   // RX_magical_fight.pde
    case 8: enemyResultScene();   break;   // RX_magical_fight.pde
  }

  checkMagicResult();
  checkItemResult();
  checkGameEnd();
}

// =============================================
// 戦闘メニュー画面
// =============================================
void battleScene() {
  camera();
  background(120, 200, 255);

  // 草
  fill(70, 170, 70);
  rect(0, height-120, width, 120);

  // タイトル
  fill(255);
  textSize(28);
  text("BATTLE", width/2, 30);

  //--------------------------
  // プレイヤー情報ウィンドウ
  //--------------------------
  fill(255,240);
  stroke(0);
  strokeWeight(3);
  rect(20,20,220,110,15);

  fill(0);
  textAlign(LEFT,CENTER);
  textSize(18);
  text("PLAYER",35,40);

  // HPバー
  fill(180);
  rect(80,60,120,15);

  fill(0,220,0);
  rect(80,60,map(player.hp,0,100,0,120),15);

  fill(0);
  text("HP",35,67);
  text(player.hp+"/100",205,67);

  // MPバー
  fill(180);
  rect(80,90,120,15);

  fill(30,120,255);
  rect(80,90,map(player.mp,0,50,0,120),15);

  fill(0);
  text("MP",35,97);
  text(player.mp+"/50",205,97);

  //--------------------------
  // 敵情報
  //--------------------------
  fill(255,240);
  rect(width-240,20,220,80,15);

  fill(0);
  text("SLIME",width-210,40);

  fill(180);
  rect(width-180,60,120,15);

  fill(255,60,60);
  rect(width-180,60,map(enemy.hp,0,120,0,120),15);

  fill(0);
  text(enemy.hp+"/120",width-55,67);

  //--------------------------
  // 敵描画
  //--------------------------
  drawSlime(width/2,220);

  //--------------------------
  // メッセージ
  //--------------------------
  fill(255,250);
  rect(20,330,width-40,70,15);

  fill(0);
  textAlign(LEFT,CENTER);
  textSize(18);

  if(playerTurn)
    text("あなたのターン",40,350);
  else
    text("敵のターン",40,350);

  text(message,40,380);

  //--------------------------
  // ボタン
  //--------------------------
  drawButton(60,415,170,45,"たたかう");
  drawButton(410,415,170,45,"どうぐ");

  textAlign(CENTER,CENTER);
}

// =============================================
// 勝利・敗北
// =============================================
void winScene() {
  camera();
  background(100, 255, 100);
  fill(0);
  textSize(60);
  text("YOU WIN!", width/2, height/2);
}

void loseScene() {
  camera();
  background(255, 100, 100);
  fill(0);
  textSize(60);
  text("GAME OVER", width/2, height/2);
}

// =============================================
// 魔法陣の結果を受け取る
// =============================================
void checkMagicResult() {
  if (magicFinished) {
    enemy.hp   -= magicDamage;
    message     = "魔法成功！ " + magicDamage + " ダメージ";
    magicFinished = false;
    playerTurn  = false;
    startEnemyDefense();
  }
}

// 道具の結果を受け取る
void checkItemResult() {
  if (itemFinished) {
    itemFinished = false;
    playerTurn   = false;
    startEnemyDefense();
  }
}

// 防御ミニゲームへ移行
void startEnemyDefense() {
  enemyAttackType = int(random(2));
  guardSuccess    = false;
  timer           = 0;
  scene           = 5;
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
  message   = "HPを30回復！";
  itemFinished = true;
}

void usePowerItem() {
  player.attack += 10;
  message = "攻撃力アップ！";
  itemFinished = true;
}

void useBombItem() {
  enemy.hp = max(enemy.hp - 20, 0);
  message = "Bomb！ 敵に20ダメージ！";
  itemFinished = true;
}

// =============================================
// 入力処理
// =============================================
void mousePressed() {

  if (scene == 0 && playerTurn) {

    if (mouseX > 60 &&
        mouseX < 230 &&
        mouseY > 415 &&
        mouseY < 460) {

      scene = 1;
    }

    if (mouseX > 410 &&
        mouseX < 580 &&
        mouseY > 415 &&
        mouseY < 460) {

      scene = 2;
    }

  }
  else if(scene==1){
    magicMousePressed();
  }
  else if(scene==6){
    flickMousePressed();
  }

}
void keyPressed() {
  // ESCキーでアプリが終了しないようにする
  if (keyCode == ESC) {
    key = 0;
    if (scene == 1 || scene == 2) {
      scene = 0;  // 戦闘画面へ戻る
    }
    return;
  }

  if (scene == 1) {
    magicKeyPressed();   // KONOdemo_v1.pde
  }
  if (scene == 2) {
    itemKeyPressed();    // Tool.pde
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

void drawSlime(float x, float y){

  pushMatrix();
  translate(x,y);

  noStroke();

  // 影
  fill(0,70);
  ellipse(0,55,90,18);

  // スライム
  fill(70,170,255);

  beginShape();
  vertex(0,-70);

  bezierVertex(-55,-35,-60,20,-40,50);
  bezierVertex(-15,80,15,80,40,50);
  bezierVertex(60,20,55,-35,0,-70);

  endShape(CLOSE);

  // 光沢
  fill(255,180);
  ellipse(-18,-28,18,18);

  // 目
  fill(255);
  ellipse(-15,-5,18,22);
  ellipse(15,-5,18,22);

  fill(0);
  ellipse(-15,0,6,10);
  ellipse(15,0,6,10);

  // 口
  noFill();
  stroke(0);
  strokeWeight(3);
  arc(0,25,35,15,0,PI);

  popMatrix();
}

void drawButton(float x,float y,float w,float h,String s){

  fill(40,70,180);
  stroke(255);
  strokeWeight(3);

  rect(x,y,w,h,12);

  fill(255);
  textAlign(CENTER,CENTER);
  textSize(22);
  text(s,x+w/2,y+h/2);
}

class Enemy {
  int hp, attack;
  Enemy(int hp, int attack) {
    this.hp     = hp;
    this.attack = attack;
  }
}
