// ============================================================
// KONOdemo_v1.pde  ★ 魔法陣担当 ★
//
// このファイルが担当するシーン
//   scene == 1 : 魔法陣画面
//
// メインとの連携方法
//   評価完了時に  magicDamage = ダメージ値;
//                magicFinished = true;
//   を設定すると、Ziyuukadai2026.pde が結果を受け取ります。
//
// 【ステップ1】トラッキング高速化
// 【ステップ2】複数ストローク対応
// 【ステップ3】自前の幾何判定（〇△□）
// 【ステップ4】魔法陣らしさスコア
//   ①図形数(40) ＋ ②外周円(30) ＋ ③同心度(30) ＝ 最大100点
//   ダメージ = 面積由来の基礎値 × (1 + スコア/100)
// ============================================================

// ---- 魔法陣専用変数 ----
color trackColor;
float threshold  = 25;
float smoothedX  = 0;
float smoothedY  = 0;
float easing     = 0.15;

// ---- 高速トラッキング用 ----
boolean targetLocked = false;
int     searchR      = 60;

// ---- 結果表示用 ----
boolean showingResult = false;
int     resultTimer   = 0;
int     RESULT_FRAMES = 180;   // スコアも見せるので少し延長（約3秒）
int     pendingDamage = 0;
int     magicScore    = 0;     // 魔法陣らしさ（0〜100）
String  scoreDetail   = "";    // スコアの内訳表示用

// ---- 図形認識のパラメータ ----
int   RESAMPLE_N    = 64;
int   CORNER_WINDOW = 3;
float CORNER_ANGLE  = 55;
float CLOSE_RATIO   = 0.30;
float CIRCLE_CV_MAX = 0.22;

// ---- ストローク管理 ----
ArrayList<ArrayList<PVector>> strokes;
ArrayList<PVector> currentStroke;
ArrayList<MagicShape> recognizedShapes;
int MIN_STROKE_POINTS = 10;

boolean isDrawing  = false;
String  resultText = "魔法色をクリックで選択 / スペース:描画 / Enter:発動";
int     elementColor;

// ---- 図形の種類 ----
final int SHAPE_CIRCLE   = 0;
final int SHAPE_TRIANGLE = 1;
final int SHAPE_SQUARE   = 2;

// =============================================
// 認識した図形1つ分の情報をまとめるクラス
// =============================================
class MagicShape {
  int     type;
  float   area;
  PVector center;
  ArrayList<PVector> outline;

  MagicShape(int type, float area, PVector center, ArrayList<PVector> outline) {
    this.type    = type;
    this.area    = area;
    this.center  = center;
    this.outline = outline;
  }

  // 円とみなしたときの半径（面積から逆算: area = πr²）
  float radius() {
    return sqrt(area / PI);
  }

  String label() {
    if (type == SHAPE_CIRCLE)   return "〇";
    if (type == SHAPE_TRIANGLE) return "△";
    return "□";
  }

  color shapeColor() {
    if (type == SHAPE_CIRCLE)   return color( 50, 150, 255);
    if (type == SHAPE_TRIANGLE) return color(255,  50,  50);
    return color(200, 150, 50);
  }
}

// =============================================
// 初期化（Ziyuukadai2026 の setup() から呼ばれる）
// =============================================
void initMagic() {
  surface.setLocation((displayWidth  - width)  / 2,
                      (displayHeight - height) / 2);

  strokes          = new ArrayList<ArrayList<PVector>>();
  currentStroke    = new ArrayList<PVector>();
  recognizedShapes = new ArrayList<MagicShape>();
  trackColor   = color(255, 0, 0);
  elementColor = color(255);
}

// =============================================
// 魔法陣画面の描画（scene == 1 のとき呼ばれる）
// =============================================
void magicDrawScene() {
  camera();
  hint(DISABLE_DEPTH_TEST);

  if (video == null) {
    background(30);
    fill(255);
    textSize(24);
    text("カメラが見つかりません", width/2, height/2);
    textSize(16);
    text("Escキーで戻る", width/2, height/2 + 50);
    return;
  }

  video.loadPixels();
  image(video, 0, 0, width, height);

  if (showingResult) {
    drawMagicResult();
    return;
  }

  // ---- 1. 色トラッキング（高速版）----
  float scaleX = (float)width  / video.width;
  float scaleY = (float)height / video.height;

  int tr = (trackColor >> 16) & 0xFF;
  int tg = (trackColor >>  8) & 0xFF;
  int tb =  trackColor        & 0xFF;
  float thSq = threshold * threshold;

  int x0, y0, x1, y1, step;
  if (targetLocked) {
    int cx = int(smoothedX / scaleX);
    int cy = int(smoothedY / scaleY);
    x0 = max(cx - searchR, 0);
    y0 = max(cy - searchR, 0);
    x1 = min(cx + searchR, video.width);
    y1 = min(cy + searchR, video.height);
    step = 2;
  } else {
    x0 = 0;  y0 = 0;
    x1 = video.width;  y1 = video.height;
    step = 4;
  }

  float sumX = 0, sumY = 0;
  int   count = 0;

  for (int y = y0; y < y1; y += step) {
    int row = y * video.width;
    for (int x = x0; x < x1; x += step) {
      color c  = video.pixels[row + x];
      int   dr = ((c >> 16) & 0xFF) - tr;
      int   dg = ((c >>  8) & 0xFF) - tg;
      int   db = ( c        & 0xFF) - tb;
      if (dr*dr + dg*dg + db*db < thSq) {
        sumX += x;
        sumY += y;
        count++;
      }
    }
  }

  if (count > 3) {
    targetLocked = true;
    smoothedX = lerp(smoothedX, (sumX / count) * scaleX, easing);
    smoothedY = lerp(smoothedY, (sumY / count) * scaleY, easing);

    fill(trackColor);
    strokeWeight(4.0);
    stroke(255);
    ellipse(smoothedX, smoothedY, 20, 20);
    noStroke();

    if (isDrawing) {
      int last = currentStroke.size() - 1;
      boolean far = (last < 0) ||
                    dist(smoothedX, smoothedY,
                         currentStroke.get(last).x,
                         currentStroke.get(last).y) > 5;
      if (far) currentStroke.add(new PVector(smoothedX, smoothedY));
    }
  } else {
    targetLocked = false;
  }

  // ---- 2. 描いた軌跡を表示 ----
  stroke(elementColor);
  strokeWeight(6);
  noFill();
  for (ArrayList<PVector> s : strokes) {
    beginShape();
    for (PVector p : s) vertex(p.x, p.y);
    endShape();
  }
  if (currentStroke.size() > 0) {
    beginShape();
    for (PVector p : currentStroke) vertex(p.x, p.y);
    endShape();
  }

  // ---- 3. UI ----
  fill(0, 160);
  noStroke();
  rect(0, 0, width, 55);
  fill(255);
  textSize(18);
  textAlign(LEFT, CENTER);
  text(resultText + "  [図形数: " + strokes.size() + "]", 10, 27);
  textAlign(RIGHT, CENTER);
  text("Cキー: クリア  |  Escキー: 戻る", width - 10, 27);
  textAlign(CENTER, CENTER);
}

// =============================================
// 結果表示画面
// =============================================
void drawMagicResult() {
  // 描いた全ストローク（薄い下書き）
  stroke(255, 120);
  strokeWeight(4);
  noFill();
  for (ArrayList<PVector> s : strokes) {
    beginShape();
    for (PVector p : s) vertex(p.x, p.y);
    endShape();
  }

  // 認識できた図形
  for (MagicShape ms : recognizedShapes) {
    stroke(ms.shapeColor());
    strokeWeight(8);
    fill(ms.shapeColor(), 90);
    beginShape();
    for (PVector p : ms.outline) vertex(p.x, p.y);
    endShape(CLOSE);

    fill(255);
    textSize(28);
    text(ms.label(), ms.center.x, ms.center.y);
  }

  // 半透明の帯と結果テキスト
  fill(0, 170);
  noStroke();
  rect(0, height/2 - 85, width, 175);

  fill(elementColor);
  textAlign(CENTER, CENTER);
  textSize(26);
  text(resultText, width/2, height/2 - 55);

  fill(255, 220, 80);
  textSize(20);
  text("魔法陣らしさ: " + magicScore + "点  (" + scoreDetail + ")",
       width/2, height/2 - 15);

  fill(255);
  textSize(26);
  text("ダメージ: " + pendingDamage, width/2, height/2 + 25);
  textSize(14);
  text("Enterでバトルに戻る", width/2, height/2 + 62);

  resultTimer++;
  if (resultTimer > RESULT_FRAMES) {
    finishMagic();
  }
}

// =============================================
// 結果をメインに渡して戦闘画面へ戻る
// =============================================
void finishMagic() {
  magicDamage   = pendingDamage;
  magicFinished = true;

  strokes.clear();
  currentStroke.clear();
  recognizedShapes.clear();
  showingResult = false;
  resultText    = "魔法色をクリックで選択 / スペース:描画 / Enter:発動";
  elementColor  = color(255);
  scene = 0;
}

// =============================================
// 描き終わった線を strokes に確定させる
// =============================================
void commitStroke() {
  if (currentStroke.size() >= MIN_STROKE_POINTS) {
    strokes.add(currentStroke);
  }
  currentStroke = new ArrayList<PVector>();
}

// =============================================
// マウス処理
// =============================================
void magicMousePressed() {
  if (video == null || showingResult) return;
  int vx  = int(mouseX * (float)video.width  / width);
  int vy  = int(mouseY * (float)video.height / height);
  int loc = vx + vy * video.width;
  if (loc >= 0 && loc < video.pixels.length) {
    trackColor   = video.pixels[loc];
    smoothedX    = mouseX;
    smoothedY    = mouseY;
    targetLocked = false;
  }
}

// =============================================
// キー処理
// =============================================
void magicKeyPressed() {
  if (showingResult) {
    if (key == ENTER || key == RETURN) finishMagic();
    return;
  }

  if (key == ' ') {
    isDrawing = true;
  } else if (key == ENTER || key == RETURN) {
    commitStroke();
    evaluateMagicCircle();
  } else if (key == 'c' || key == 'C') {
    strokes.clear();
    currentStroke.clear();
    recognizedShapes.clear();
    resultText   = "待機中...";
    elementColor = color(255);
  }
}

void keyReleased() {
  if (scene != 1) return;
  if (key == ' ') {
    isDrawing = false;
    commitStroke();
  }
}

// =============================================
// ★★ 図形認識 ★★
// =============================================

// ---------------------------------------------
// 魔法陣を評価してダメージを計算
// ---------------------------------------------
void evaluateMagicCircle() {
  if (strokes.size() == 0) {
    resultText = "魔力が足りません（何も描かれていません）";
    return;
  }

  recognizedShapes.clear();
  int failed = 0;

  for (ArrayList<PVector> s : strokes) {
    MagicShape ms = recognizeStroke(s);
    if (ms != null) recognizedShapes.add(ms);
    else            failed++;
  }

  // ---- 基礎ダメージ（面積の合計）----
  int baseDamage = 0;
  int nCircle = 0, nTri = 0, nSq = 0;
  for (MagicShape ms : recognizedShapes) {
    baseDamage += max(5, int(ms.area / 400));
    if      (ms.type == SHAPE_CIRCLE)   nCircle++;
    else if (ms.type == SHAPE_TRIANGLE) nTri++;
    else                                nSq++;
  }

  // ---- 魔法陣らしさスコア → ダメージ倍率 ----
  magicScore = calcMagicScore();

  if (recognizedShapes.size() > 0) {
    pendingDamage = int(baseDamage * (1.0 + magicScore / 100.0));

    resultText = "認識: ";
    if (nCircle > 0) resultText += "〇×" + nCircle + " ";
    if (nTri    > 0) resultText += "△×" + nTri    + " ";
    if (nSq     > 0) resultText += "□×" + nSq     + " ";
    if (failed  > 0) resultText += "(失敗" + failed + "本)";
    elementColor = color(255);
  } else {
    pendingDamage = 1;
    magicScore    = 0;
    scoreDetail   = "図形なし";
    resultText    = "魔法不発...（図形を認識できず）";
    elementColor  = color(150);
  }

  showingResult = true;
  resultTimer   = 0;
}

// ---------------------------------------------
// 魔法陣らしさスコア（0〜100点）
//   ①図形数: 1つ10点、最大40点
//   ②外周円: 最大の円が他の全図形を内包していれば30点
//   ③同心度: 内側の図形の中心が外周円の中心に近いほど最大30点
// ---------------------------------------------
int calcMagicScore() {
  int n = recognizedShapes.size();
  if (n == 0) return 0;

  // ① 図形数
  int scoreCount = min(n, 4) * 10;

  // ② 外周円を探す: 円タイプの中で面積最大のもの
  MagicShape outer = null;
  for (MagicShape ms : recognizedShapes) {
    if (ms.type == SHAPE_CIRCLE) {
      if (outer == null || ms.area > outer.area) outer = ms;
    }
  }

  int scoreOuter  = 0;
  int scoreCenter = 0;

  if (outer != null && n >= 2) {
    float r = outer.radius();

    // 他の全図形の重心が外周円の内側にあるかチェック
    boolean allInside = true;
    float   sumRatio  = 0;   // 中心ズレの割合（0=完全同心、1=縁ギリギリ）
    int     innerCount = 0;

    for (MagicShape ms : recognizedShapes) {
      if (ms == outer) continue;
      float d = dist(ms.center.x, ms.center.y,
                     outer.center.x, outer.center.y);
      if (d > r) allInside = false;
      sumRatio += min(d / r, 1.0);
      innerCount++;
    }

    if (allInside) {
      scoreOuter = 30;
      // ③ 同心度: ズレ割合の平均が0なら30点、1なら0点
      float avgRatio = sumRatio / innerCount;
      scoreCenter = int(30 * (1.0 - avgRatio));
    }
  }

  scoreDetail = "図形" + scoreCount + " 外円" + scoreOuter + " 同心" + scoreCenter;
  return scoreCount + scoreOuter + scoreCenter;
}

// ---------------------------------------------
// ストローク1本を認識する
// ---------------------------------------------
MagicShape recognizeStroke(ArrayList<PVector> raw) {

  ArrayList<PVector> pts = resampleStroke(raw, RESAMPLE_N);
  if (pts == null) return null;

  float minX = Float.MAX_VALUE, minY = Float.MAX_VALUE;
  float maxX = -Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
  for (PVector p : pts) {
    minX = min(minX, p.x);  maxX = max(maxX, p.x);
    minY = min(minY, p.y);  maxY = max(maxY, p.y);
  }
  float diag = dist(minX, minY, maxX, maxY);
  if (diag < 40) return null;

  float gap = dist(pts.get(0).x, pts.get(0).y,
                   pts.get(pts.size()-1).x, pts.get(pts.size()-1).y);
  boolean closed = (gap < diag * CLOSE_RATIO);

  int corners = countCorners(pts);

  PVector center = new PVector(0, 0);
  for (PVector p : pts) center.add(p);
  center.div(pts.size());

  float meanR = 0;
  for (PVector p : pts) meanR += dist(p.x, p.y, center.x, center.y);
  meanR /= pts.size();
  float varR = 0;
  for (PVector p : pts) {
    float d = dist(p.x, p.y, center.x, center.y) - meanR;
    varR += d * d;
  }
  float cv = sqrt(varR / pts.size()) / meanR;

  println("認識デバッグ: closed=" + closed + "  corners=" + corners
          + "  cv=" + nf(cv, 1, 2) + "  gap/diag=" + nf(gap/diag, 1, 2));

  if (!closed) return null;

  float area = polygonArea(pts);
  if (corners <= 1 && cv < CIRCLE_CV_MAX) {
    return new MagicShape(SHAPE_CIRCLE, area, center, pts);
  } else if (corners == 3) {
    return new MagicShape(SHAPE_TRIANGLE, area, center, pts);
  } else if (corners == 4) {
    return new MagicShape(SHAPE_SQUARE, area, center, pts);
  }
  return null;
}

// ---------------------------------------------
// リサンプリング: 線を等間隔の n 点に打ち直す
// ---------------------------------------------
ArrayList<PVector> resampleStroke(ArrayList<PVector> raw, int n) {
  if (raw.size() < 2) return null;

  float total = 0;
  for (int i = 1; i < raw.size(); i++) {
    total += dist(raw.get(i-1).x, raw.get(i-1).y,
                  raw.get(i).x,   raw.get(i).y);
  }
  if (total < 1) return null;

  float interval = total / n;
  ArrayList<PVector> out = new ArrayList<PVector>();
  out.add(raw.get(0).copy());

  float acc = 0;
  for (int i = 1; i < raw.size(); i++) {
    PVector prev = raw.get(i-1);
    PVector cur  = raw.get(i);
    float   d    = dist(prev.x, prev.y, cur.x, cur.y);

    while (acc + d >= interval && out.size() < n) {
      float t  = (interval - acc) / d;
      PVector q = PVector.lerp(prev, cur, t);
      out.add(q);
      prev = q;
      d    = dist(prev.x, prev.y, cur.x, cur.y);
      acc  = 0;
    }
    acc += d;
  }
  return out;
}

// ---------------------------------------------
// 角の数を数える
// ---------------------------------------------
int countCorners(ArrayList<PVector> pts) {
  int n = pts.size();
  int k = CORNER_WINDOW;
  boolean[] isCorner = new boolean[n];

  for (int i = 0; i < n; i++) {
    PVector a = pts.get((i - k + n) % n);
    PVector b = pts.get(i);
    PVector c = pts.get((i + k) % n);

    PVector v1 = PVector.sub(b, a);
    PVector v2 = PVector.sub(c, b);
    float angle = degrees(PVector.angleBetween(v1, v2));

    isCorner[i] = (angle > CORNER_ANGLE);
  }

  int corners = 0;
  for (int i = 0; i < n; i++) {
    boolean prev = isCorner[(i - 1 + n) % n];
    if (isCorner[i] && !prev) corners++;
  }
  return corners;
}

// ---------------------------------------------
// 靴ひも公式で閉じた多角形の面積を求める
// ---------------------------------------------
float polygonArea(ArrayList<PVector> pts) {
  float sum = 0;
  int n = pts.size();
  for (int i = 0; i < n; i++) {
    PVector p1 = pts.get(i);
    PVector p2 = pts.get((i + 1) % n);
    sum += p1.x * p2.y - p2.x * p1.y;
  }
  return abs(sum) / 2;
}
