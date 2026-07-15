// 処理の流れ:
//   色トラッキング → ストローク記録 → リサンプリング
//   → 図形分類→ 魔法陣スコア算出 → ダメージ変換

// 色トラッキング用
color trackColor;              // 追跡する色
float threshold  = 25;         // 色の許容範囲
float smoothedX  = 0;          // 手ブレ補正後のペン先座標
float smoothedY  = 0;
float easing     = 0.15;       // 平滑化の強さ

// 探索窓
boolean targetLocked = false;  // 前フレームで色を見つけられたか
int     searchR      = 60;     // 探索窓の半径．

// 結果表示用
boolean showingResult = false; // 結果表示モード（この間は描画入力を止める）
int     resultTimer   = 0;
int     RESULT_FRAMES = 180;   // 結果表示時間
int     pendingDamage = 0;     // メインへ渡す前のダメージの一時保管
int     magicScore    = 0;     // 魔法陣らしさ
String  scoreDetail   = "";    // スコアの内訳

// 図形認識のパラメータ
int   RESAMPLE_N    = 64;    // リサンプリング後の点数
int   CORNER_WINDOW = 3;     // 角度を測る際に何点前後を見るか
float CORNER_ANGLE  = 55;    // これ以上曲がっていれば角とみなす（度）
float CLOSE_RATIO   = 0.30;  // 始点終点間が対角線の30%未満なら"閉じている"と判定
float CIRCLE_CV_MAX = 0.22;  // 半径の変動係数がこれ以下なら円

// ストローク管理
ArrayList<ArrayList<PVector>> strokes;   // 描き終わった線の集合
ArrayList<PVector> currentStroke;        // いま描いている最中の線
ArrayList<MagicShape> recognizedShapes;  // 認識に成功した図形のリスト
int MIN_STROKE_POINTS = 10;              // これ未満の線はノイズとして捨てる

boolean isDrawing  = false;
String  resultText = "魔法色をクリックで選択 / スペース:描画 / Enter:発動";
int     elementColor;

// 図形の種類
final int SHAPE_CIRCLE   = 0;
final int SHAPE_TRIANGLE = 1;
final int SHAPE_SQUARE   = 2;





// 認識した図形1つ分の情報をまとめるクラス
class MagicShape {
  int     type;                 // 図形の種類
  float   area;                 // 面積
  PVector center;               // 重心
  ArrayList<PVector> outline;   // 表示用の輪郭点列

  MagicShape(int type, float area, PVector center, ArrayList<PVector> outline) {
    this.type    = type;
    this.area    = area;
    this.center  = center;
    this.outline = outline;
  }

  // 面積から半径を逆算する（外周円が他の図形を内包しているかの判定に必要）
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




// 初期化（メインの setup() から呼ばれる）
void initMagic() {
  // ウィンドウを中央に配置する
  surface.setLocation((displayWidth  - width)  / 2,
                      (displayHeight - height) / 2);

  strokes          = new ArrayList<ArrayList<PVector>>();
  currentStroke    = new ArrayList<PVector>();
  recognizedShapes = new ArrayList<MagicShape>();
  trackColor   = color(255, 0, 0);
  elementColor = color(255);
}





// 魔法陣画面の描画
void magicDrawScene() {
  camera();
  hint(DISABLE_DEPTH_TEST);   // P3Dの奥行き判定を無効化し2D描画を確実に手前へ

  if (video == null) {
    background(30);
    fill(255);
    textSize(24);
    text("カメラが見つかりません", width/2, height/2);
    textSize(16);
    text("Escキーで戻る", width/2, height/2 + 50);
    return;
  }

  video.loadPixels();                    // 画素配列へアクセス可能にする
  image(video, 0, 0, width, height);     // カメラ映像を背景として表示

  // 結果表示中はトラッキングも描画入力も行わない
  if (showingResult) {
    drawMagicResult();
    return;
  }

  // 色トラッキング
  float scaleX = (float)width  / video.width;   // カメラ座標→画面座標の倍率
  float scaleY = (float)height / video.height;

  // ビット演算で成分を取り出す
  int tr = (trackColor >> 16) & 0xFF;
  int tg = (trackColor >>  8) & 0xFF;
  int tb =  trackColor        & 0xFF;

  // d < t と d² < t² は同値なので，閾値側を2乗しておけば平方根の計算を省ける
  float thSq = threshold * threshold;

  // 探索範囲の決定
  int x0, y0, x1, y1, step;
  if (targetLocked) {
    int cx = int(smoothedX / scaleX);   // 画面座標→カメラ座標
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

  for (int y = y0; y < y1; y += step) {  // 縦方向　step飛ばしにして処理数を下げている．
  int row = y * video.width;   // 行頭の添字を先に計算し内側ループの乗算を省く
    for (int x = x0; x < x1; x += step) {  // 横方向
      color c  = video.pixels[row + x];
      int   dr = ((c >> 16) & 0xFF) - tr;
      int   dg = ((c >>  8) & 0xFF) - tg;
      int   db = ( c        & 0xFF) - tb;
      // RGB空間のユークリッド距離の二乗が閾値内なら追跡色とみなす
      if (dr*dr + dg*dg + db*db < thSq) {
        sumX += x;               // 該当画素の座標をすべて合計
        sumY += y;
        count++;
      }
    }
  }

  if (count > 3) {               // 数画素以上見つかれば有効な検出とする
    targetLocked = true;
    // 合計÷個数＝重心．最近傍1点方式よりノイズ画素の影響を受けにくい
    // lerpでローパスフィルタをかける（平滑化）
    smoothedX = lerp(smoothedX, (sumX / count) * scaleX, easing);
    smoothedY = lerp(smoothedY, (sumY / count) * scaleY, easing);

    // ペン先カーソルの表示
    fill(trackColor);
    strokeWeight(4.0);
    stroke(255);
    ellipse(smoothedX, smoothedY, 20, 20);
    noStroke();

    if (isDrawing) {
      // 前の点から5px以上離れたときだけ記録する
      // 静止中に同じ場所へ点が大量に溜まるのを防ぐ
      int last = currentStroke.size() - 1;
      boolean far = (last < 0) ||
                    dist(smoothedX, smoothedY,
                         currentStroke.get(last).x,
                         currentStroke.get(last).y) > 5;
      if (far) currentStroke.add(new PVector(smoothedX, smoothedY));
    }
  } else {
    targetLocked = false;        // 見失った → 次フレームは全画面走査に戻す
  }

  // 描いた軌跡を表示
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

// UI
  fill(0, 160);
  noStroke();
  rect(0, 0, width, 55);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(17);
  if (textWidth(resultText) > width - 20) {
    textSize(17 * (width - 20) / textWidth(resultText));
  }
  text(resultText, 10, 16);
  textSize(13);
  fill(220);
  text("スペース:描画 / Enter:発動 / C:クリア / Esc:戻る", 10, 41);
  textAlign(RIGHT, CENTER);
  text("[図形数: " + strokes.size() + "]", width - 10, 41);
  textAlign(CENTER, CENTER);
}









// 結果表示画面
void drawMagicResult() {
  // 描いた全ストロークは薄い下書きとして残す
  stroke(255, 120);
  strokeWeight(4);
  noFill();
  for (ArrayList<PVector> s : strokes) {
    beginShape();
    for (PVector p : s) vertex(p.x, p.y);
    endShape();
  }

  // 認識できた図形を種類別の色で塗って重ね，判定結果を可視化する
  for (MagicShape ms : recognizedShapes) {
    stroke(ms.shapeColor());
    strokeWeight(8);
    fill(ms.shapeColor(), 90);
    beginShape();
    for (PVector p : ms.outline) vertex(p.x, p.y);
    endShape(CLOSE);

    fill(255);
    textSize(28);
    text(ms.label(), ms.center.x, ms.center.y);   // 重心に〇△□のラベル
  }

  // 結果テキスト・スコア内訳・ダメージを表示
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

  // 一定時間で自動的に戻る（Enterでスキップも可能）
  resultTimer++;
  if (resultTimer > RESULT_FRAMES) {
    finishMagic();
  }
}









// 結果をメインへ渡して戦闘画面へ戻る
void finishMagic() {
  magicDamage   = pendingDamage;
  magicFinished = true;

  // 次回に備えて状態をすべて初期化する
  strokes.clear();
  currentStroke.clear();
  recognizedShapes.clear();
  showingResult = false;
  resultText    = "魔法色をクリックで選択 / スペース:描画 / Enter:発動";
  elementColor  = color(255);
  scene = 0;
}







// 描き終わった線を strokes に確定させる
void commitStroke() {
  if (currentStroke.size() >= MIN_STROKE_POINTS) {
    strokes.add(currentStroke);              // 確定リストへ移す
  }
  currentStroke = new ArrayList<PVector>();  // 新しい空の線を用意する
}









// クリック位置の画素色を追跡色に設定する
void magicMousePressed() {
  if (video == null || showingResult) return;
  // 画面座標→カメラ座標に変換してから画素を参照する
  int vx  = int(mouseX * (float)video.width  / width);
  int vy  = int(mouseY * (float)video.height / height);
  int loc = vx + vy * video.width;
  if (loc >= 0 && loc < video.pixels.length) {
    trackColor   = video.pixels[loc];
    smoothedX    = mouseX;
    smoothedY    = mouseY;
    targetLocked = false;   // 色を選び直したら全画面走査からやり直す
  }
}






// スペース:描画  Enter:発動  C:クリア
void magicKeyPressed() {
  if (showingResult) {
    if (key == ENTER || key == RETURN) finishMagic();
    return;
  }

  if (key == ' ') {
    isDrawing = true;
  } else if (key == ENTER || key == RETURN) {
    commitStroke(); // 描きかけの線があれば確定してから評価する
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
  if (scene != 1) return;    // 魔法陣画面以外では反応させない
  if (key == ' ') {
    isDrawing = false;
    commitStroke();          // スペースを離した＝1本描き終わり
  }
}







// 図形認識
void evaluateMagicCircle() {
  if (strokes.size() == 0) {
    resultText = "魔力が足りません（何も描かれていません）";
    return;
  }

  recognizedShapes.clear();
  int failed = 0;

  // ストローク1本ずつ独立に認識にかける
  for (ArrayList<PVector> s : strokes) {
    MagicShape ms = recognizeStroke(s);
    if (ms != null) recognizedShapes.add(ms);
    else            failed++;
  }

  // 面積の合計
  int baseDamage = 0;
  int nCircle = 0, nTri = 0, nSq = 0;
  for (MagicShape ms : recognizedShapes) {
    baseDamage += max(5, int(ms.area / 400));   // 400は難易度調整用の係数
    if      (ms.type == SHAPE_CIRCLE)   nCircle++;
    else if (ms.type == SHAPE_TRIANGLE) nTri++;
    else                                nSq++;
  }

  // 魔法陣らしさスコアで倍率をかける
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

  // すぐには戻らず結果表示モードへ入る
  showingResult = true;
  resultTimer   = 0;
}






// 魔法陣らしさ
int calcMagicScore() {
  int n = recognizedShapes.size();
  if (n == 0) return 0;

  // 図形数による加点
  int scoreCount = min(n, 4) * 10;

  // 外周円候補
  MagicShape outer = null;
  for (MagicShape ms : recognizedShapes) {
    if (ms.type == SHAPE_CIRCLE) {
      if (outer == null || ms.area > outer.area) outer = ms;
    }
  }

  int scoreOuter  = 0;
  int scoreCenter = 0;

  if (outer != null && n >= 2) {
    float r = outer.radius();   // 面積から逆算した半径

    boolean allInside = true;
    float   sumRatio  = 0;      // 中心ズレの割合（0=完全同心，1=縁ギリギリ）
    int     innerCount = 0;

    for (MagicShape ms : recognizedShapes) {
      if (ms == outer) continue;
      // 重心間距離が半径未満なら内側にあると判定する
      float d = dist(ms.center.x, ms.center.y,
                     outer.center.x, outer.center.y);
      if (d > r) allInside = false;
      sumRatio += min(d / r, 1.0);
      innerCount++;
    }

    if (allInside) {
      scoreOuter = 30;
      // ズレ割合の平均が0なら30点，1なら0点になるよう線形配点
      float avgRatio = sumRatio / innerCount;
      scoreCenter = int(30 * (1.0 - avgRatio));
    }
  }

  scoreDetail = "図形" + scoreCount + " 外円" + scoreOuter + " 同心" + scoreCenter;
  return scoreCount + scoreOuter + scoreCenter;
}








// ストローク1本を認識
MagicShape recognizeStroke(ArrayList<PVector> raw) {
    
  // 等間隔の64点に打ち直す
  ArrayList<PVector> pts = resampleStroke(raw, RESAMPLE_N);
  if (pts == null) return null;

  // 外接矩形の対角線＝図形の「大きさ」の基準として使う
  float minX = Float.MAX_VALUE, minY = Float.MAX_VALUE;
  float maxX = -Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
  for (PVector p : pts) {
    minX = min(minX, p.x);  maxX = max(maxX, p.x);
    minY = min(minY, p.y);  maxY = max(maxY, p.y);
  }
  float diag = dist(minX, minY, maxX, maxY);
  if (diag < 40) return null;   // 小さすぎる図形は無効

  // 閉合判定
  float gap = dist(pts.get(0).x, pts.get(0).y,
                   pts.get(pts.size()-1).x, pts.get(pts.size()-1).y);
  boolean closed = (gap < diag * CLOSE_RATIO);

  // 角の数を数える
  int corners = countCorners(pts);

  // 重心
  PVector center = new PVector(0, 0);
  for (PVector p : pts) center.add(p);
  center.div(pts.size());

  // 円らしさ
  float meanR = 0;
  for (PVector p : pts) meanR += dist(p.x, p.y, center.x, center.y);
  meanR /= pts.size();
  float varR = 0;
  for (PVector p : pts) {
    float d = dist(p.x, p.y, center.x, center.y) - meanR;
    varR += d * d;
  }
  float cv = sqrt(varR / pts.size()) / meanR;


  if (!closed) return null;

  // 角の数と円らしさで各図形に振り分ける
  float area = polygonArea(pts);
  if (corners <= 1 && cv < CIRCLE_CV_MAX) {
    return new MagicShape(SHAPE_CIRCLE, area, center, pts);
  } else if (corners == 3) {
    return new MagicShape(SHAPE_TRIANGLE, area, center, pts);
  } else if (corners == 4) {
    return new MagicShape(SHAPE_SQUARE, area, center, pts);
  }
  return null;   // どれにも当てはまらなければ認識失敗
}










// リサンプリング
ArrayList<PVector> resampleStroke(ArrayList<PVector> raw, int n) {
  if (raw.size() < 2) return null;

  // 線の全長を測る
  float total = 0;
  for (int i = 1; i < raw.size(); i++) {
    total += dist(raw.get(i-1).x, raw.get(i-1).y,
                  raw.get(i).x,   raw.get(i).y);
  }
  if (total < 1) return null;

  float interval = total / n;   // 1区間の長さ
  ArrayList<PVector> out = new ArrayList<PVector>();
  out.add(raw.get(0).copy());

  float acc = 0;   // 前の打ち直し点からの累積距離
  for (int i = 1; i < raw.size(); i++) {
    PVector prev = raw.get(i-1);
    PVector cur  = raw.get(i);
    float   d    = dist(prev.x, prev.y, cur.x, cur.y);

    // 区間の途中に打ち直し点が入る場合は線形補間で座標を求める
    while (acc + d >= interval && out.size() < n) {
      float t  = (interval - acc) / d;        // 区間内での位置（0〜1）
      PVector q = PVector.lerp(prev, cur, t);
      out.add(q);
      prev = q;                                // 打った点を新たな起点にする
      d    = dist(prev.x, prev.y, cur.x, cur.y);
      acc  = 0;
    }
    acc += d;
  }
  return out;
}








// 角の数を数える
int countCorners(ArrayList<PVector> pts) {
  int n = pts.size();
  int k = CORNER_WINDOW;
  boolean[] isCorner = new boolean[n];

  for (int i = 0; i < n; i++) {
    // 閉じた図形として扱うため，端の添字は剰余(% n)で反対側へ循環させる
    PVector a = pts.get((i - k + n) % n);
    PVector b = pts.get(i);
    PVector c = pts.get((i + k) % n);

    PVector v1 = PVector.sub(b, a);   // 入ってくる方向
    PVector v2 = PVector.sub(c, b);   // 出ていく方向
    float angle = degrees(PVector.angleBetween(v1, v2));

    isCorner[i] = (angle > CORNER_ANGLE);
  }

  // 塊の立ち上がりを数える
  int corners = 0;
  for (int i = 0; i < n; i++) {
    boolean prev = isCorner[(i - 1 + n) % n];
    if (isCorner[i] && !prev) corners++;
  }
  return corners;
}




// ガウスの面積公式
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
