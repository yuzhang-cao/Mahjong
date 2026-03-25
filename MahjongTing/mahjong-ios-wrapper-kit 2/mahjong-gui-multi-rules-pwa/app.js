// 麻将听牌助手（图形化，广东/四川）
// 牌库覆盖：
// - 四川：万筒条（27）
// - 广东：万筒条（27）+ 字牌（东南西北中发白，7）= 34
// - 花牌：春夏秋冬梅兰竹菊（8），只做记录，不计入 13/14 张，也不参与胡牌形判定
//
// 自动模式：手里出现字/花 -> 广东；否则 -> 四川
// 仅判定“能否胡/听哪些牌”，不算番，不处理起胡番数限制

(function () {
  'use strict';
  function $(id) { return document.getElementById(id); }

  // Elements
  var elRuleMode = $('rule_mode');
  var elRuleBadge = $('rule_badge');

  var elQiDui = $('opt_qidui');
  var el13yao = $('opt_13yao');
  var lbl13yao = $('lbl_13yao');

  var elDingqueRow = $('dingque_row');
  var elDingque = $('dingque');
  var elFlowerHint = $('flower_hint');

  var handArea = $('hand_area');
  var handStatus = $('hand_status');
  var panelStatus = $('panel_status');

  var out = $('out');
  var status = $('status');

  var btnCalc = $('btnCalc');
  var btnClear = $('btnClear');
  var btnUndo = $('btnUndo');

  var tileGrid = $('tile_grid');

  var tabs = {
    m: $('tab_m'),
    p: $('tab_p'),
    s: $('tab_s'),
    z: $('tab_z'),
    f: $('tab_f')
  };

  // State
  var counts34 = new Array(34);
  for (var i = 0; i < 34; i++) counts34[i] = 0;

  var flowers = new Array(8);
  for (var j = 0; j < 8; j++) flowers[j] = 0;

  var history = []; // {kind:'tile'|'flower', idx:int}
  var currentTab = 'm';

  // -------------------------
  // Basic helpers
  // -------------------------
  function sumCounts34() {
    var s = 0;
    for (var i = 0; i < 34; i++) s += counts34[i];
    return s;
  }

  function sumFlowers() {
    var s = 0;
    for (var i = 0; i < 8; i++) s += flowers[i];
    return s;
  }

  function hasHonorOrFlower() {
    for (var i = 27; i < 34; i++) if (counts34[i] > 0) return true;
    for (var j = 0; j < 8; j++) if (flowers[j] > 0) return true;
    return false;
  }

  function resolveMode() {
    var sel = elRuleMode.value;
    if (sel === 'sichuan') return 'sichuan';
    if (sel === 'guangdong') return 'guangdong';
    return hasHonorOrFlower() ? 'guangdong' : 'sichuan';
  }

  function suitName(suit) {
    if (suit === 'm') return '万';
    if (suit === 'p') return '筒';
    if (suit === 's') return '条';
    return '';
  }

  function honorName(n) {
    if (n === 1) return '东';
    if (n === 2) return '南';
    if (n === 3) return '西';
    if (n === 4) return '北';
    if (n === 5) return '中';
    if (n === 6) return '发';
    return '白';
  }

  function flowerName(i) {
    var names = ['春', '夏', '秋', '冬', '梅', '兰', '竹', '菊'];
    return names[i] || ('花' + String(i + 1));
  }

  function tileIdx(suit, num) {
    var base = (suit === 'm') ? 0 : (suit === 'p' ? 9 : 18);
    return base + (num - 1);
  }

  function tileName(idx) {
    if (idx >= 27) return honorName(idx - 27 + 1);
    var suit = (idx < 9) ? 'm' : (idx < 18 ? 'p' : 's');
    var num = (idx < 9) ? (idx + 1) : (idx < 18 ? (idx - 9 + 1) : (idx - 18 + 1));
    return String(num) + suitName(suit);
  }

  function suitOf27(idx) {
    if (idx < 9) return 'm';
    if (idx < 18) return 'p';
    return 's';
  }

  function countSuit27(counts, suit) {
    var base = (suit === 'm') ? 0 : (suit === 'p' ? 9 : 18);
    var s = 0;
    for (var i = 0; i < 9; i++) s += counts[base + i];
    return s;
  }

  function maxCount(kind) {
    if (kind === 'flower') return 1;
    return 4;
  }

  // -------------------------
  // UI rendering
  // -------------------------
  function setActiveTab(tab) {
    currentTab = tab;
    for (var k in tabs) {
      if (!tabs.hasOwnProperty(k)) continue;
      tabs[k].classList.toggle('active', k === tab);
    }
    renderGrid();
  }

  function updateRuleUI() {
    var mode = resolveMode();
    var sel = elRuleMode.value;

    if (sel === 'auto') {
      elRuleBadge.textContent = '当前：自动（' + (mode === 'sichuan' ? '四川' : '广东') + '）';
    } else {
      elRuleBadge.textContent = '当前：' + (mode === 'sichuan' ? '四川' : '广东');
    }

    if (mode === 'sichuan') {
      elDingqueRow.style.display = '';
      el13yao.disabled = true;
      lbl13yao.style.opacity = '0.4';
      elFlowerHint.style.display = 'none';

      tabs.z.disabled = true;
      tabs.f.disabled = true;

      if (currentTab === 'z' || currentTab === 'f') setActiveTab('m');
    } else {
      elDingqueRow.style.display = 'none';
      el13yao.disabled = false;
      lbl13yao.style.opacity = '1';
      elFlowerHint.style.display = '';

      tabs.z.disabled = false;
      tabs.f.disabled = false;
    }
  }

  function renderHand() {
    handArea.innerHTML = '';

    var items = [];
    for (var i = 0; i < 34; i++) {
      if (counts34[i] > 0) items.push({ kind: 'tile', idx: i, cnt: counts34[i] });
    }
    for (var j = 0; j < 8; j++) {
      if (flowers[j] > 0) items.push({ kind: 'flower', idx: j, cnt: flowers[j] });
    }

    if (items.length === 0) {
      var empty = document.createElement('div');
      empty.className = 'status';
      empty.textContent = '尚未点牌。先在下方选择“万/筒/条/字/花”，再点牌加入。';
      handArea.appendChild(empty);
    } else {
      items.sort(function (a, b) {
        // tile before flower; within tile: numeric suits (0..26) before honors (27..33)
        if (a.kind !== b.kind) return (a.kind === 'tile') ? -1 : 1;
        return a.idx - b.idx;
      });

      for (var k = 0; k < items.length; k++) {
        (function () {
          var it = items[k];
          var chip = document.createElement('button');
          chip.type = 'button';
          chip.className = 'chip';
          var name = (it.kind === 'tile') ? tileName(it.idx) : flowerName(it.idx);
          chip.textContent = name + ' × ' + it.cnt + '（点我减一）';
          chip.addEventListener('click', function () {
            decrement(it.kind, it.idx);
          });
          handArea.appendChild(chip);
        })();
      }
    }

    renderStatusLine();
    renderGrid();
  }

  function renderStatusLine() {
    updateRuleUI();

    var mode = resolveMode();
    var handCnt = sumCounts34();   // 不含花
    var flowerCnt = sumFlowers();
    var msg = [];

    msg.push('手牌：<b>' + handCnt + '</b> 张（不含花）');
    if (flowerCnt > 0) msg.push('；花牌：<b>' + flowerCnt + '</b> 张');
    msg.push('；模式：<b>' + (mode === 'sichuan' ? '四川' : '广东') + '</b>');

    if (elRuleMode.value === 'sichuan' && hasHonorOrFlower()) {
      msg.push('；<span class="danger">已点入字/花牌，但规则选了四川：请改成广东或清空字/花</span>');
    }

    if (handCnt > 14) {
      msg.push('；<span class="danger">超过 14 张（当前 ' + handCnt + '）</span>');
    } else if (handCnt < 13) {
      msg.push('；<span class="warn">少于 13 张（当前 ' + handCnt + '）</span>');
    } else if (handCnt === 13) {
      msg.push('；<b>可算听牌</b>');
    } else {
      msg.push('；<b>可算出牌方案/是否已胡</b>');
    }

    if (mode === 'sichuan') {
      var dq = (elDingque.value === 'none') ? null : elDingque.value;
      if (dq) {
        var dqCount = countSuit27(counts34, dq);
        if (dqCount > 0) msg.push('；<span class="warn">未清缺：缺门 ' + suitName(dq) + ' 还有 ' + dqCount + ' 张</span>');
      }
    }

    handStatus.innerHTML = msg.join('');
    panelStatus.textContent = '点下面的牌加入；点上方条目撤销。';
  }

  function renderGrid() {
    tileGrid.innerHTML = '';
    var mode = resolveMode();
    var tab = currentTab;

    if (mode === 'sichuan' && (tab === 'z' || tab === 'f')) tab = 'm';

    if (tab === 'm' || tab === 'p' || tab === 's') {
      for (var n = 1; n <= 9; n++) {
        var idx = tileIdx(tab, n);
        tileGrid.appendChild(makeTileButton('tile', idx, String(n) + suitName(tab), counts34[idx]));
      }
      return;
    }

    if (tab === 'z') {
      for (var h = 1; h <= 7; h++) {
        var idxZ = 27 + (h - 1);
        tileGrid.appendChild(makeTileButton('tile', idxZ, honorName(h), counts34[idxZ]));
      }
      return;
    }

    if (tab === 'f') {
      for (var f = 0; f < 8; f++) {
        tileGrid.appendChild(makeTileButton('flower', f, flowerName(f), flowers[f]));
      }
      return;
    }
  }

  function makeTileButton(kind, idx, label, cnt) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'tile';
    btn.textContent = label;

    var small = document.createElement('small');
    small.textContent = (kind === 'tile') ? '点一下 +1' : '花牌（记录）';
    btn.appendChild(small);

    if (cnt > 0) {
      var badge = document.createElement('div');
      badge.className = 'badge';
      badge.textContent = '×' + cnt;
      btn.appendChild(badge);
    }

    btn.addEventListener('click', function () { increment(kind, idx); });
    return btn;
  }

  // -------------------------
  // Mutations: increment/decrement/undo/clear
  // -------------------------
  function increment(kind, idx) {
    var mode = resolveMode();

    // 若用户手动选四川，不允许点入字/花（直接拦截）
    if (elRuleMode.value === 'sichuan') {
      if (kind === 'flower' || (kind === 'tile' && idx >= 27)) {
        status.textContent = '（输入限制）';
        out.textContent = '你当前选择了“四川麻将”，四川一般不使用字牌/花牌。\n请切换为“广东麻将”或改为“自动”，或先清空字/花。';
        return;
      }
    }

    // 四川模式（自动判定）下也不允许点字/花
    if (mode === 'sichuan') {
      if (kind === 'flower' || (kind === 'tile' && idx >= 27)) {
        status.textContent = '（提示）';
        out.textContent = '当前按“四川麻将”处理（手里没有字/花）。\n如果你要用字牌/花牌，请把规则切到“广东”或点入字/花以触发自动切换。';
        return;
      }
    }

    if (kind === 'tile') {
      if (counts34[idx] >= maxCount('tile')) return;
      counts34[idx] += 1;
      history.push({ kind: 'tile', idx: idx });
    } else {
      if (flowers[idx] >= maxCount('flower')) return;
      flowers[idx] += 1;
      history.push({ kind: 'flower', idx: idx });
    }

    updateAfterChange();
  }

  function decrement(kind, idx) {
    if (kind === 'tile') {
      if (counts34[idx] <= 0) return;
      counts34[idx] -= 1;
    } else {
      if (flowers[idx] <= 0) return;
      flowers[idx] -= 1;
    }
    // 不强行修历史（简化）；撤销最后一张只按 history 来做
    updateAfterChange();
  }

  function undoLast() {
    if (history.length === 0) return;
    var last = history.pop();
    if (last.kind === 'tile') {
      if (counts34[last.idx] > 0) counts34[last.idx] -= 1;
    } else {
      if (flowers[last.idx] > 0) flowers[last.idx] -= 1;
    }
    updateAfterChange();
  }

  function clearAll() {
    for (var i = 0; i < 34; i++) counts34[i] = 0;
    for (var j = 0; j < 8; j++) flowers[j] = 0;
    history = [];
    status.textContent = '';
    out.textContent = '请先点牌录入手牌，然后点击“计算”。';
    updateAfterChange();
  }

  function updateAfterChange() {
    updateRuleUI();
    renderHand();
  }

  // -------------------------
  // Mahjong core: winning checks
  // -------------------------
  // 记忆化（数牌拆面子）
  var suitMemo = new Map();

  function suitKey(a9) {
    var key = 0;
    for (var i = 0; i < 9; i++) key = key * 5 + a9[i];
    return key;
  }

  function sliceSuit(counts, base) {
    var a9 = new Array(9);
    for (var i = 0; i < 9; i++) a9[i] = counts[base + i];
    return a9;
  }

  function canSuitFormMelds(a9) {
    var key = suitKey(a9);
    if (suitMemo.has(key)) return suitMemo.get(key);

    var i = 0;
    while (i < 9 && a9[i] === 0) i++;
    if (i === 9) { suitMemo.set(key, true); return true; }

    // 刻子
    if (a9[i] >= 3) {
      a9[i] -= 3;
      if (canSuitFormMelds(a9)) { a9[i] += 3; suitMemo.set(key, true); return true; }
      a9[i] += 3;
    }

    // 顺子
    if (i <= 6 && a9[i] >= 1 && a9[i + 1] >= 1 && a9[i + 2] >= 1) {
      a9[i] -= 1; a9[i + 1] -= 1; a9[i + 2] -= 1;
      if (canSuitFormMelds(a9)) { a9[i] += 1; a9[i + 1] += 1; a9[i + 2] += 1; suitMemo.set(key, true); return true; }
      a9[i] += 1; a9[i + 1] += 1; a9[i + 2] += 1;
    }

    suitMemo.set(key, false);
    return false;
  }

  function isQiDui(counts, N) {
    var pairs = 0;
    for (var i = 0; i < N; i++) {
      if (counts[i] % 2 !== 0) return false;
      pairs += counts[i] / 2;
    }
    return pairs === 7;
  }

  function isThirteenOrphans(counts34) {
    // 1/9万筒条 + 东南西北中发白 各一张，再多其中任意一张作将
    var required = [0,8,9,17,18,26,27,28,29,30,31,32,33];
    var hasPair = false;

    for (var i = 0; i < required.length; i++) {
      var idx = required[i];
      if (counts34[idx] === 0) return false;
      if (counts34[idx] >= 2) hasPair = true;
    }
    // 其他牌必须为 0
    for (var t = 0; t < 34; t++) {
      var inReq = false;
      for (var j = 0; j < required.length; j++) {
        if (required[j] === t) { inReq = true; break; }
      }
      if (!inReq && counts34[t] !== 0) return false;
    }
    return hasPair;
  }

  function canAllMelds27(counts27) {
    return canSuitFormMelds(sliceSuit(counts27, 0)) &&
           canSuitFormMelds(sliceSuit(counts27, 9)) &&
           canSuitFormMelds(sliceSuit(counts27, 18));
  }

  function canAllMelds34(counts34) {
    if (!canSuitFormMelds(sliceSuit(counts34, 0))) return false;
    if (!canSuitFormMelds(sliceSuit(counts34, 9))) return false;
    if (!canSuitFormMelds(sliceSuit(counts34, 18))) return false;
    for (var i = 27; i < 34; i++) {
      if (counts34[i] % 3 !== 0) return false;
    }
    return true;
  }

  function isWinning(counts, mode, dq, enableQiDui, enable13yao) {
    // counts: length 27 or 34
    var N = counts.length;
    var total = 0;
    for (var i = 0; i < N; i++) total += counts[i];
    if (total !== 14) return false;

    if (mode === 'sichuan' && dq) {
      if (countSuit27(counts, dq) !== 0) return false;
    }

    if (enableQiDui && isQiDui(counts, N)) return true;
    if (mode === 'guangdong' && enable13yao && isThirteenOrphans(counts)) return true;

    for (var pair = 0; pair < N; pair++) {
      if (counts[pair] >= 2) {
        counts[pair] -= 2;
        var ok = (mode === 'sichuan') ? canAllMelds27(counts) : canAllMelds34(counts);
        counts[pair] += 2;
        if (ok) return true;
      }
    }
    return false;
  }

  function calcWaitsFrom13(counts13, mode, dq, enableQiDui, enable13yao) {
    var N = counts13.length;
    var waits = [];

    // 四川：未清缺不听（按常见规则）
    if (mode === 'sichuan' && dq && countSuit27(counts13, dq) !== 0) return waits;

    for (var t = 0; t < N; t++) {
      if (counts13[t] >= 4) continue;

      // 四川：不考虑摸到缺门牌
      if (mode === 'sichuan' && dq) {
        if (suitOf27(t) === dq) continue;
      }

      counts13[t] += 1;
      var ok = isWinning(counts13, mode, dq, enableQiDui, enable13yao);
      counts13[t] -= 1;
      if (ok) waits.push(t);
    }
    return waits;
  }

  function listDiscards(counts) {
    var res = [];
    for (var i = 0; i < counts.length; i++) if (counts[i] > 0) res.push(i);
    return res;
  }

  function calcSuggestionsFrom14(counts14, discards, mode, dq, enableQiDui, enable13yao) {
    var res = [];
    for (var i = 0; i < discards.length; i++) {
      var d = discards[i];
      counts14[d] -= 1;

      var waits = calcWaitsFrom13(counts14, mode, dq, enableQiDui, enable13yao);
      if (waits.length > 0) res.push({ discard: d, waits: waits.slice() });

      counts14[d] += 1;
    }
    res.sort(function (a, b) {
      if (b.waits.length !== a.waits.length) return b.waits.length - a.waits.length;
      return a.discard - b.discard;
    });
    return res;
  }

  function waitsToString(waits, mode) {
    var arr = [];
    for (var i = 0; i < waits.length; i++) arr.push(tileName(waits[i]));
    return arr.join('、');
  }

  // -------------------------
  // Calculation action
  // -------------------------
  function calculate() {
    var mode = resolveMode();
    var enableQiDui = (elQiDui.value === 'on');
    var enable13yao = (el13yao.value === 'on') && (mode === 'guangdong');

    var dq = null;
    if (mode === 'sichuan') dq = (elDingque.value === 'none') ? null : elDingque.value;

    // 若用户手动选四川但含字/花：阻止计算（避免误判）
    if (elRuleMode.value === 'sichuan' && hasHonorOrFlower()) {
      status.textContent = '（无法计算）';
      out.textContent = '你选择了“四川麻将”，但手里包含字牌/花牌。\n请切换为“广东麻将”或改为“自动”，或清空字/花牌后再算。';
      return;
    }

    var handCnt = sumCounts34(); // 不含花
    if (handCnt !== 13 && handCnt !== 14) {
      status.textContent = '（张数不满足）';
      out.textContent = '需要 13 张（算听牌）或 14 张（算出牌方案）。\n当前手牌（不含花）为：' + handCnt + ' 张。';
      return;
    }

    // 构造工作数组
    var counts;
    if (mode === 'sichuan') {
      counts = counts34.slice(0, 27);
    } else {
      counts = counts34.slice(0, 34);
    }

    var lines = [];
    status.textContent = '（规则：' + (mode === 'sichuan' ? '四川' : '广东') + '；已识别 ' + handCnt + ' 张）';

    // 四川定缺提示
    if (mode === 'sichuan' && dq) {
      var dqCount = countSuit27(counts, dq);
      if (dqCount > 0) {
        lines.push('【定缺】你设置了定缺：' + suitName(dq) + '。当前缺门牌还有 ' + dqCount + ' 张。');
        lines.push('按四川麻将常见规则：未清缺不能胡/不能听；且通常必须先打缺门。');
        lines.push('');
      }
    }

    if (handCnt === 13) {
      var waits = calcWaitsFrom13(counts, mode, dq, enableQiDui, enable13yao);
      lines.push('【13 张】听牌列表：');
      if (mode === 'sichuan' && dq && countSuit27(counts, dq) !== 0) {
        lines.push('未清缺，按常见规则：不能听牌。');
      } else if (waits.length === 0) {
        lines.push('未找到可胡牌（当前不听牌）。');
      } else {
        lines.push('听 ' + waits.length + ' 种：' + waitsToString(waits, mode));
        lines.push('');
        lines.push('【理论剩余张数（仅扣除你手牌，不考虑场面明牌）】');
        for (var i = 0; i < waits.length; i++) {
          var t = waits[i];
          var remain = 4 - counts[t];
          lines.push('- ' + tileName(t) + '：最多还剩 ' + remain + ' 张');
        }
      }
      lines.push('');
      lines.push('（七对：' + (enableQiDui ? '开' : '关') + '；十三幺：' + (enable13yao ? '开' : '关') + '）');
    } else {
      // 14 张：出牌建议
      var discards = listDiscards(counts);

      // 四川：若未清缺 -> 只建议打缺门牌
      if (mode === 'sichuan' && dq && countSuit27(counts, dq) !== 0) {
        var filtered = [];
        for (var i = 0; i < discards.length; i++) {
          if (suitOf27(discards[i]) === dq) filtered.push(discards[i]);
        }
        discards = filtered;
      }

      var suggestions = calcSuggestionsFrom14(counts, discards, mode, dq, enableQiDui, enable13yao);
      lines.push('【14 张】出牌后听牌方案：');
      if (suggestions.length === 0) {
        lines.push('没有找到任何出牌后能听牌的方案。');
      } else {
        var limit = Math.min(12, suggestions.length);
        for (var k = 0; k < limit; k++) {
          var s = suggestions[k];
          lines.push('打出：' + tileName(s.discard) + '  ->  听 ' + s.waits.length + ' 种：' + waitsToString(s.waits, mode));
        }
        if (suggestions.length > limit) {
          lines.push('');
          lines.push('（仅展示前 ' + limit + ' 条，共 ' + suggestions.length + ' 条；可在 app.js 调整展示数量。）');
        }
      }

      // 当前是否已胡
      var winNow = isWinning(counts, mode, dq, enableQiDui, enable13yao);
      lines.push('');
      lines.push('【当前 14 张是否已胡】' + (winNow ? '是（可胡）' : '否（未胡）'));
    }

    out.textContent = lines.join('\n');
  }

  // -------------------------
  // Events
  // -------------------------
  elRuleMode.addEventListener('change', function () {
    // 若从广东切到四川，且已有字/花：提示但不强制清空
    renderStatusLine();
    renderGrid();
  });

  elDingque.addEventListener('change', function () { renderStatusLine(); });
  elQiDui.addEventListener('change', function () { /* no-op */ });
  el13yao.addEventListener('change', function () { /* no-op */ });

  for (var t in tabs) {
    if (!tabs.hasOwnProperty(t)) continue;
    (function (tab) {
      tabs[tab].addEventListener('click', function () {
        if (tabs[tab].disabled) return;
        setActiveTab(tab);
      });
    })(t);
  }

  btnUndo.addEventListener('click', function () { undoLast(); });
  btnClear.addEventListener('click', function () { clearAll(); });
  btnCalc.addEventListener('click', function () { calculate(); });

  // initial
  updateAfterChange();

})();
