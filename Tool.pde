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
// 
//カメラ画像から肌色領域を探し、グーチョキパーを判定
//
// ID対応
// -1 : 手を認識していない
//  0 : パー   / Herb 回復
//  1 : グー  / Bomb
//  2 : チョキ / Power Seed 攻撃力アップ
// ============================================================

// ENTERを押して確定したアイテム
int selectedItemId = -1;

// 現在の手の形に対応する3Dモデル
int previewItemId = -1;

boolean itemUsed = false;

int itemEffectFrame = 0;
int effectWait = 60;

boolean waitingEffect = false;
boolean waitingNextScene = false;
int effectStartFrame = 0;

// 判定を安定させるための変数
int lastHandId = -1;
int stableCount = 0;
int stableHandId = -1;

// 認識範囲
int handRoiX = 160;
int handRoiY = 40;
int handRoiW = 320;
int handRoiH = 320;

// 0：確認画面
// 1：カメラ判定画面
int itemToolState = 0;

PImage debugSkinMask;

float debugWhiteRatio = 0;
int debugWhitePixels = 0;
int debugRoiPixels = 0;

// ============================================================
// メインプログラムの scene == 2 から呼ばれる
// ============================================================
//緑の枠内のみを認識対象に
void itemARScene() {
  camera();
  hint(DISABLE_DEPTH_TEST);

  // ===============================
  // 0 : 最初の確認画面
  // ===============================
  if (itemToolState == 0) {
    drawItemStartScene();
    return;
  }

  // ===============================
  // 1 : カメラでハンドサイン判定
  // ===============================
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

  // 手を置く認識範囲
  noFill();
  stroke(0, 255, 100);
  strokeWeight(3);
  rect(handRoiX, handRoiY, handRoiW, handRoiH);

  fill(0, 180);
  noStroke();
  rect(handRoiX, handRoiY - 30, handRoiW, 26);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(15);
  text(
    "この枠の中に手を入れてください",
    handRoiX + handRoiW / 2,
    handRoiY - 17
  );

  if (!itemUsed) {
    // 現在の手の形を判定
    previewItemId = detectHandSignByContour();
  }

  if (itemUsed) {
    drawSelectedItemModel(selectedItemId);
  }
  else if (previewItemId != -1) {
    drawSelectedItemModel(previewItemId);
  }
  
  // 効果表示後に自動で次画面へ
  if (waitingEffect) {

    int elapsed = frameCount - effectStartFrame;

    if (elapsed >= 120) { // 約2秒
 
      waitingEffect = false;

      // ここで初めて効果を適用
      useItemByHandSign(selectedItemId);

      resetItemTool();

      scene = 0;

      return;
    }
  }

  drawItemUI();
}

void drawItemStartScene() {
  background(20, 25, 35);

  fill(255);
  textAlign(CENTER, CENTER);

  textSize(36);
  text("どうぐを使いますか？", width / 2, height / 2 - 90);

  textSize(22);
  text("ENTER : カメラを起動して道具を選ぶ", width / 2, height / 2 - 20);
  text("R : 戦闘画面にもどる", width / 2, height / 2 + 25);

  textSize(16);
  text("グーチョキパーをカメラに見せて道具を選択", width / 2, height / 2 + 90);
}


// ============================================================
// 白ピクセル割合でグーチョキパーを判定
// ============================================================
int detectHandSignByContour() {
  if (video == null) {
    return stabilizeHandId(-1);
  }

  video.loadPixels();

  if (video.pixels == null || video.pixels.length == 0) {
    return stabilizeHandId(-1);
  }

  // ----------------------------------------------------------
  // Processing画面のROI座標をカメラ画像の座標へ変換
  // ----------------------------------------------------------
  int videoRoiX = int(handRoiX * video.width / (float)width);
  int videoRoiY = int(handRoiY * video.height / (float)height);
  int videoRoiW = int(handRoiW * video.width / (float)width);
  int videoRoiH = int(handRoiH * video.height / (float)height);

  // カメラ画像の範囲からはみ出さないようにする
  videoRoiX = constrain(videoRoiX, 0, video.width - 1);
  videoRoiY = constrain(videoRoiY, 0, video.height - 1);

  videoRoiW = constrain(
    videoRoiW,
    1,
    video.width - videoRoiX
  );

  videoRoiH = constrain(
    videoRoiH,
    1,
    video.height - videoRoiY
  );

  // ----------------------------------------------------------
  // 肌色判定用のマスク画像を作成
  // ----------------------------------------------------------
  PImage mask = createImage(video.width, video.height, RGB);
  mask.loadPixels();

  int whitePixelCount = 0;
  int roiPixelCount = 0;

  for (int y = 0; y < video.height; y++) {
    for (int x = 0; x < video.width; x++) {
      int index = x + y * video.width;

      boolean insideRoi =
        x >= videoRoiX &&
        x < videoRoiX + videoRoiW &&
        y >= videoRoiY &&
        y < videoRoiY + videoRoiH;

      // ROIの外側は黒にする
      if (!insideRoi) {
        mask.pixels[index] = color(0);
        continue;
      }

      roiPixelCount++;

      color c = video.pixels[index];

      float r = red(c);
      float g = green(c);
      float b = blue(c);

      float maxValue = max(r, max(g, b));
      float minValue = min(r, min(g, b));

      // 簡易的な肌色判定
      boolean isSkin =
        r > 70 &&
        g > 35 &&
        b > 20 &&
        r > g &&
        r > b &&
        maxValue - minValue > 15 &&
        abs(r - g) > 8;

      if (isSkin) {
        mask.pixels[index] = color(255);
        whitePixelCount++;
      } else {
        mask.pixels[index] = color(0);
      }
    }
  }

  mask.updatePixels();

  // デバッグ表示用に保存
  debugSkinMask = mask;

  // ----------------------------------------------------------
  // ROI内に占める白ピクセルの割合を計算
  // ----------------------------------------------------------
  float whiteRatio = 0;

  if (roiPixelCount > 0) {
    whiteRatio =
      whitePixelCount / (float)roiPixelCount;
  }

  debugWhitePixels = whitePixelCount;
  debugRoiPixels = roiPixelCount;
  debugWhiteRatio = whiteRatio;

  // ----------------------------------------------------------
  // 白ピクセルの割合で判定
  // ----------------------------------------------------------
  int currentId = -1;

  // 5%未満なら手がない
  if (whiteRatio < 0.05) {
    currentId = -1;

  // 5%以上、30%未満ならグー
  } else if (whiteRatio < 0.30) {
    currentId = 1;

  // 30%以上、45%未満ならチョキ
  } else if (whiteRatio < 0.45) {
    currentId = 2;

  // 45%以上ならパー
  } else {
    currentId = 0;
  }

  println(
    "whitePixels=" + whitePixelCount +
    " roiPixels=" + roiPixelCount +
    " whiteRatio=" + nf(whiteRatio, 1, 3) +
    " whitePercent=" + nf(whiteRatio * 100, 1, 1) + "%" +
    " result=" + getHandSignName(currentId)
  );

  return currentId;
}

//安定関数を追加
int stabilizeHandId(int currentId) {
  if (currentId == lastHandId) {
    stableCount++;
  } else {
    lastHandId = currentId;
    stableCount = 1;
  }

  // 同じ結果が8フレーム続いたら採用
  if (stableCount >= 8) {
    stableHandId = currentId;
  }

  return stableHandId;
}

//手の形の名前を取得する
String getHandSignName(int id) {
  if (id == 0) {
    return "パー";
  } else if (id == 1) {
    return "グー";
  } else if (id == 2) {
    return "チョキ";
  }

  return "未認識";
}


// ============================================================
// 選択された道具の3Dモデル表示
// ============================================================
void drawSelectedItemModel(int id) {
  hint(ENABLE_DEPTH_TEST);

  pushMatrix();

  lights();

  translate(width / 2, height / 2 - 50, 0);

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

  // 道具の最初の確認画面
  if (itemToolState == 0) {

    // ENTERでカメラ判定画面へ
    if (key == ENTER || key == RETURN || keyCode == ENTER) {
      itemToolState = 1;

      selectedItemId = -1;
      previewItemId = -1;
      itemUsed = false;
      itemEffectFrame = 0;

      lastHandId = -1;
      stableCount = 0;
      stableHandId = -1;

      message = "手を画面中央に見せてください";
      return;
    }

    // Rで戦闘画面へ戻る
    if (key == 'r' || key == 'R') {
      resetItemTool();
      scene = 0;
      return;
    }
  }

    // カメラ判定画面
    else if (itemToolState == 1) {

    // ENTERで現在表示中の道具を確定して使用
    if (key == ENTER || key == RETURN || keyCode == ENTER) {
   
      // 手を認識していない場合は確定しない
      if (previewItemId == -1) {
        message = "手の形を認識できていません";
        return;
      }

      // すでに使用済みなら再使用しない
      if (itemUsed) {
        return;
      }

      // 現在表示している道具を確定
      selectedItemId = previewItemId;
      
      itemUsed = true;

      waitingEffect = true;
      effectStartFrame = frameCount;

      // 効果を画面に表示
      message =
        getItemName(selectedItemId) +
        "を使用：" +
        getItemEffectText(selectedItemId);

      return;
    }

    // Rで戦闘画面へ戻る
    if (key == 'r' || key == 'R') {
      resetItemTool();
      scene = 0;
      return;
    }
  }
}


// ============================================================
// 道具使用
// ============================================================
void useItemByHandSign(int id) {

  if (id == 0) {
    useHealItem();
  }
  else if (id == 1) {
    useBombItem();
  }
  else if (id == 2) {
    usePowerItem();
  }

  itemUsed = true;

  effectStartFrame = frameCount;
  waitingNextScene = true;
}


// ============================================================
// UI
// ============================================================
void drawItemUI() {
  int panelY = 300;

  fill(0, 190);
  noStroke();
  rect(0, panelY, width, height - panelY);

  fill(255);
  textAlign(LEFT, CENTER);

  textSize(22);
  text("道具を選択", 20, panelY + 25);

  textSize(16);
  text(
    "パー：Herb   チョキ：Power Seed   グー：Bomb",
    20,
    panelY + 55
  );

  textSize(18);
  text(
    "現在の判定：" + getHandSignName(previewItemId),
    20,
    panelY + 85
  );

  text(
    "表示中：" + getItemName(previewItemId),
    20,
    panelY + 112
  );

  textSize(14);
  text(
    "白ピクセル=" + debugWhitePixels +
    "  白色割合=" + nf(debugWhiteRatio * 100, 1, 1) + "%",
    20,
    panelY + 138
  );

  textSize(16);
  text(message, 20, panelY + 165);

  textAlign(RIGHT, CENTER);

  if (!itemUsed) {
    text("ENTER：使用", width - 20, panelY + 85);
  } else {
    text("道具を使用しました", width - 20, panelY + 85);
  }

  text("R / ESC：戻る", width - 20, panelY + 115);
  
  if (debugSkinMask != null) {
    image(debugSkinMask, width - 210, 10, 200, 150);

    fill(0, 180);
    noStroke();
    rect(width - 210, 160, 200, 25);

   fill(255);
    textAlign(CENTER, CENTER);
    textSize(13);
    text("肌色判定マスク", width - 110, 172);
  }

  if (waitingEffect) {

    fill(0, 200);
    rect(70, 120, 500, 90);

    fill(255, 255, 0);
    textAlign(CENTER, CENTER);
    textSize(30);

    text(
      getItemName(selectedItemId) + " 発動！",
      width / 2,
      165
    );
  }

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
  previewItemId = -1;

  itemUsed = false;

  waitingNextScene = false;
  effectStartFrame = 0;

  itemEffectFrame = 0;

  lastHandId = -1;
  stableCount = 0;
  stableHandId = -1;

  itemToolState = 0;
}
