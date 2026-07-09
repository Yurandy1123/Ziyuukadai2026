// ============================================================
// Tool.pde  ★ AR道具担当 ★
//
// このファイルが担当するシーン
//   scene == 2 : AR道具画面
//
// 必要ファイル（スケッチの data/ フォルダに入れてください）
//   camera_para.dat  … ARカメラキャリブレーション
//   herb.obj         … マーカーID 0 のモデル（回復薬）
//   bomb.obj         … マーカーID 1 のモデル（爆弾）
//   seed.obj         … マーカーID 2 のモデル（パワーシード）
//
// メインとの連携方法
//   道具を使ったとき useHealItem() / itemFinished = true を呼ぶと
//   Ziyuukadai2026.pde が結果を受け取って防御シーンへ移ります。
// ============================================================
// ============================================================
// Tool.pde
// 色シールによる道具選択
//
// ID対応
// -1 : なし
//  0 : パー   / 緑が多い      / Herb 回復
//  1 : グー   / 赤も緑も少ない / Bomb
//  2 : チョキ / 赤が見える    / Power Seed 攻撃力アップ
// ============================================================

int selectedItemId = -1;
boolean itemUsed = false;

int itemEffectFrame = 0;
int effectWait = 60;

// 判定を安定させるための変数
int lastHandId = -1;
int stableCount = 0;
int stableHandId = -1;

// 色の数をUIに出すため
int debugRedCount = 0;
int debugGreenCount = 0;


// ============================================================
// メインプログラムの scene == 2 から呼ばれる
// ============================================================
void itemARScene() {
  camera();
  hint(DISABLE_DEPTH_TEST);

  background(0);

  // カメラ映像表示
  if (video != null) {
    image(video, 0, 0, width, height);
  } else {
    background(30);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(24);
    text("Camera not found", width / 2, height / 2);
    return;
  }

  // まだアイテムを使っていない時だけ判定
  if (!itemUsed) {
    selectedItemId = detectHandSignByColor();
  }

  // 3Dモデル表示
  if (selectedItemId != -1) {
    drawSelectedItemModel(selectedItemId);
  }

  // アイテム使用後、少し待って戦闘画面へ戻す
  if (itemUsed) {
    if (frameCount - itemEffectFrame > effectWait) {
      resetItemTool();
      scene = 0;
    }
  }

  drawItemUI();
}


// ============================================================
// 色シールでハンドサイン判定
// ============================================================
int detectHandSignByColor() {
  if (video == null) {
    return -1;
  }

  video.loadPixels();

  int redCount = 0;
  int greenCount = 0;

  // 画面中央だけを見る
  // 背景の色を拾いにくくするため
  int startX = video.width / 4;
  int endX   = video.width * 3 / 4;
  int startY = video.height / 4;
  int endY   = video.height * 3 / 4;

  for (int y = startY; y < endY; y += 4) {
    for (int x = startX; x < endX; x += 4) {
      int index = x + y * video.width;
      color c = video.pixels[index];

      float r = red(c);
      float g = green(c);
      float b = blue(c);

      // 赤シール判定
      // 攻撃力アップ / チョキ用
      // 肌色を赤と間違えにくくするため、かなり赤が強い時だけ数える
      if (r > 180 && r > g * 1.7 && r > b * 1.7) {
        redCount++;
      }

      // 緑シール判定
      // 回復 / パー用
      if (g > 140 && g > r * 1.3 && g > b * 1.3) {
        greenCount++;
      }
    }
  }

  debugRedCount = redCount;
  debugGreenCount = greenCount;

  println("red = " + redCount + " / green = " + greenCount);

  int currentId = -1;

  // 赤が明らかに多いときだけチョキ
  if (redCount > 25 && redCount > greenCount * 2) {
    currentId = 2; // チョキ → 攻撃力アップ
  }
  // 緑が明らかに多いときだけパー
  else if (greenCount > 25 && greenCount > redCount * 2) {
    currentId = 0; // パー → 回復
  }
  // 赤も緑も少ないならグー
  else if (redCount < 8 && greenCount < 8) {
    currentId = 1; // グー → Bomb
  }
  else {
    currentId = -1;
  }

  // 安定化処理
  // 同じ判定が5フレーム続いたら採用
  if (currentId == lastHandId) {
    stableCount++;
  } else {
    stableCount = 0;
    lastHandId = currentId;
  }

  if (stableCount > 5) {
    stableHandId = currentId;
  }

  return stableHandId;
}


// ============================================================
// 選択された道具の3Dモデル表示
// ============================================================
void drawSelectedItemModel(int id) {
  hint(ENABLE_DEPTH_TEST);

  pushMatrix();

  lights();

  translate(width / 2, height / 2 - 120, 0);

  float jump = abs(sin(frameCount * 0.05)) * 8;
  translate(0, -jump, 0);

  scale(0.45);

  rotateX(radians(180));
  rotateY(frameCount * 0.01);

  if (itemModel[id] != null) {
    shape(itemModel[id]);
  }

  popMatrix();

  hint(DISABLE_DEPTH_TEST);
  camera();
}


// ============================================================
// ENTERで道具使用
// メインの keyPressed() から呼ばれる
// ============================================================
void itemKeyPressed() {
  if (key == ENTER || key == RETURN || keyCode == ENTER) {

    if (itemUsed) {
      return;
    }

    if (selectedItemId == -1) {
      message = "手を画面中央に見せてください";
      return;
    }

    useItemByHandSign(selectedItemId);
  }

  // Rキーで道具選択だけリセット
  if (key == 'r' || key == 'R') {
    resetItemTool();
  }
}


// ============================================================
// 道具使用
// ============================================================
void useItemByHandSign(int id) {
  if (id == 0) {
    useHealItem();      // メインファイルの関数
  } else if (id == 1) {
    useBombItem();      // メインファイルに追加する関数
  } else if (id == 2) {
    usePowerItem();     // メインファイルの関数
  }

  itemUsed = true;
  itemEffectFrame = frameCount;
}


// ============================================================
// UI
// ============================================================
void drawItemUI() {
  fill(0, 180);
  noStroke();
  rect(0, height / 2, width, height / 2);

  fill(255);
  textAlign(LEFT, CENTER);

  textSize(24);
  text("道具を選択", 30, height / 2 + 35);

  textSize(18);
  text("緑が多い : パー / 回復", 30, height / 2 + 75);
  text("赤が見える : チョキ / 攻撃力アップ", 30, height / 2 + 105);
  text("赤も緑も少ない : グー / Bomb", 30, height / 2 + 135);

  textSize(20);
  text("Selected : " + getItemName(selectedItemId), 30, height / 2 + 180);
  text("Effect   : " + getItemEffectText(selectedItemId), 30, height / 2 + 215);

  textSize(16);
  text("red = " + debugRedCount + " / green = " + debugGreenCount, 30, height / 2 + 245);

  textSize(20);
  text(message, 30, height / 2 + 280);

  textAlign(RIGHT, CENTER);
  textSize(18);

  if (!itemUsed) {
    text("ENTER : 使用", width - 30, height / 2 + 80);
  } else {
    text("戦闘画面に戻ります", width - 30, height / 2 + 80);
  }

  text("ESC : 戻る", width - 30, height / 2 + 115);

  textAlign(CENTER, CENTER);
}


// ============================================================
// アイテム名
// ============================================================
String getItemName(int id) {
  if (id == 0) {
    return "Herb";
  } else if (id == 1) {
    return "Bomb";
  } else if (id == 2) {
    return "Power Seed";
  }

  return "None";
}


// ============================================================
// 効果テキスト
// ============================================================
String getItemEffectText(int id) {
  if (id == 0) {
    return "HPを30回復";
  } else if (id == 1) {
    return "敵に20ダメージ";
  } else if (id == 2) {
    return "攻撃力アップ";
  }

  return "手を画面中央に見せてください";
}


// ============================================================
// リセット
// ============================================================
void resetItemTool() {
  selectedItemId = -1;
  itemUsed = false;

  itemEffectFrame = 0;

  lastHandId = -1;
  stableCount = 0;
  stableHandId = -1;

  debugRedCount = 0;
  debugGreenCount = 0;
}
