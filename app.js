const gridSize = 40;
const mmPerGrid = 100;
const canvasWidth = 3200;
const canvasHeight = 2200;

const fixtures = [
  ["toilet", "トイレ"],
  ["kitchen", "台所"],
  ["bath", "浴室"],
  ["storage", "物置"],
  ["living", "リビング"],
  ["wash", "洗面所"],
  ["porch", "ポーチ"],
  ["door", "片開き戸"],
  ["doubleDoor", "両開き戸"],
  ["sliding", "引き戸"],
  ["folding", "折れ戸"],
  ["closet", "収納"],
  ["bedroom", "寝室"],
  ["parking", "駐車場"],
];

const products = [
  { code: "BD-122", name: "35φ アッシュ丸棒ディンプル付 クリア", price: 4400, cost: 1630, unit: "m", type: "rail" },
  { code: "BD-132", name: "35φ アッシュ丸棒ディンプル付 Mオーク", price: 4400, cost: 1630, unit: "m", type: "rail" },
  { code: "BD-01B", name: "35φ ブラケット横型カバー付 ブラウン", price: 1250, cost: 470, unit: "個", type: "rail" },
  { code: "BD-08G", name: "35φ エンドブラケットカバー付 ゴールド", price: 2100, cost: 780, unit: "個", type: "rail" },
  { code: "SL-900", name: "屋内用スロープ 900mm", price: 28000, cost: 16800, unit: "台", type: "slope" },
  { code: "SL-1200", name: "屋内用スロープ 1200mm", price: 36000, cost: 21600, unit: "台", type: "slope" },
  { code: "DS-050", name: "段差解消材 50mm", price: 9800, cost: 5200, unit: "箇所", type: "step" },
  { code: "DS-100", name: "段差解消材 100mm", price: 14800, cost: 7900, unit: "箇所", type: "step" },
];

const state = {
  tool: "select",
  roomLabel: "部屋",
  zoom: 1,
  objects: [],
  lines: [],
  selectedId: null,
  drag: null,
  lineDraft: null,
};

const canvas = document.querySelector("#canvas");
const canvasStage = document.querySelector("#canvasStage");
const canvasWrap = document.querySelector(".canvas-wrap");
const lineLayer = document.querySelector("#lineLayer");
const fixtureTools = document.querySelector("#fixtureTools");
const inspectorForm = document.querySelector("#inspectorForm");
const emptyInspector = document.querySelector("#emptyInspector");
const estimateList = document.querySelector("#estimateList");
const estimatePageList = document.querySelector("#estimatePageList");
const estimatePageTotals = document.querySelector("#estimatePageTotals");
const productTableBody = document.querySelector("#productTableBody");
const productForm = document.querySelector("#productForm");

const fields = {
  type: document.querySelector("#editType"),
  label: document.querySelector("#editLabel"),
  place: document.querySelector("#editPlace"),
  product: document.querySelector("#editProduct"),
  length: document.querySelector("#editLength"),
  width: document.querySelector("#editWidth"),
  height: document.querySelector("#editHeight"),
  rotation: document.querySelector("#editRotation"),
  quantity: document.querySelector("#editQuantity"),
  unitPrice: document.querySelector("#editUnitPrice"),
  discount: document.querySelector("#editDiscount"),
  note: document.querySelector("#editNote"),
};

const money = new Intl.NumberFormat("ja-JP", {
  style: "currency",
  currency: "JPY",
  maximumFractionDigits: 0,
});

function newId(prefix) {
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function snap(value) {
  return Math.round(value / gridSize) * gridSize;
}

function toMm(px) {
  return Math.round((px / gridSize) * mmPerGrid);
}

function toPx(mm) {
  return Math.round((mm / mmPerGrid) * gridSize);
}

function setTool(tool) {
  state.tool = tool;
  document.querySelectorAll(".tool").forEach((button) => {
    button.classList.toggle("active", button.dataset.tool === tool);
  });
}

function getCanvasPoint(event) {
  const rect = canvas.getBoundingClientRect();
  return {
    x: snap((event.clientX - rect.left) / state.zoom),
    y: snap((event.clientY - rect.top) / state.zoom),
  };
}

function getSelected() {
  return state.objects.find((item) => item.id === state.selectedId) || state.lines.find((item) => item.id === state.selectedId);
}

function select(id) {
  state.selectedId = id;
  render();
}

function deleteSelected() {
  if (!state.selectedId) return;
  state.objects = state.objects.filter((item) => item.id !== state.selectedId);
  state.lines = state.lines.filter((item) => item.id !== state.selectedId);
  state.selectedId = null;
  render();
}

function defaultProductFor(type) {
  return products.find((product) => product.type === type) || products[0];
}

function createRoom(label, x, y) {
  const width = label === "廊下" ? 560 : 320;
  const height = label === "廊下" ? 160 : 240;
  state.objects.push({
    id: newId("room"),
    kind: "room",
    label,
    place: label,
    x,
    y,
    width,
    height,
    rotation: 0,
  });
  select(state.objects.at(-1).id);
}

function createFixture(fixture, x, y) {
  const size = fixtureSize(fixture[0]);
  state.objects.push({
    id: newId("fixture"),
    kind: "fixture",
    fixture: fixture[0],
    label: fixture[1],
    place: fixture[1],
    x,
    y,
    width: size.width,
    height: size.height,
    rotation: 0,
  });
  select(state.objects.at(-1).id);
}

function fixtureSize(type) {
  const sizes = {
    toilet: { width: 96, height: 82 },
    kitchen: { width: 150, height: 64 },
    bath: { width: 150, height: 92 },
    wash: { width: 96, height: 78 },
    door: { width: 116, height: 100 },
    doubleDoor: { width: 150, height: 94 },
    sliding: { width: 160, height: 50 },
    folding: { width: 150, height: 88 },
    closet: { width: 150, height: 60 },
    storage: { width: 130, height: 70 },
    porch: { width: 140, height: 62 },
    parking: { width: 160, height: 88 },
  };
  return sizes[type] || { width: 120, height: 70 };
}

function createLine(type, start, end) {
  const product = defaultProductFor(type);
  const lengthMm = Math.max(mmPerGrid, toMm(Math.hypot(end.x - start.x, end.y - start.y)));
  state.lines.push({
    id: newId(type),
    kind: "line",
    type,
    label: typeLabel(type),
    place: "",
    x1: start.x,
    y1: start.y,
    x2: end.x,
    y2: end.y,
    lengthMm,
    quantity: type === "rail" ? Number((lengthMm / 1000).toFixed(2)) : 1,
    productCode: product.code,
    productName: product.name,
    unitPrice: product.price,
    discount: 0,
    note: "",
  });
  select(state.lines.at(-1).id);
}

function typeLabel(type) {
  return { rail: "手すり", slope: "スロープ", step: "段差" }[type] || type;
}

function renderFixtures() {
  fixtureTools.innerHTML = "";
  fixtures.forEach((fixture) => {
    const button = document.createElement("button");
    button.className = "fixture-tool";
    button.dataset.tool = "fixture";
    button.dataset.fixture = fixture[0];
    button.innerHTML = `<span class="fixture-symbol">${symbolSvg(fixture[0])}</span><span>${fixture[1]}</span>`;
    button.addEventListener("click", () => {
      setTool(`fixture:${fixture[0]}`);
      document.querySelectorAll(".fixture-tool").forEach((item) => item.classList.remove("active"));
      button.classList.add("active");
    });
    fixtureTools.appendChild(button);
  });
}

function renderObjects() {
  canvas.querySelectorAll(".drawing-object,.fixture-object,.line-label").forEach((node) => node.remove());

  state.objects.forEach((item) => {
    const node = document.createElement("div");
    node.dataset.id = item.id;
    node.className = item.kind === "room" ? "drawing-object" : "fixture-object";
    node.classList.toggle("selected", item.id === state.selectedId);
    node.style.left = `${item.x}px`;
    node.style.top = `${item.y}px`;
    node.style.width = `${item.width}px`;
    node.style.height = `${item.height}px`;

    if (item.kind === "room") {
      node.innerHTML = `
        <span class="room-label">${item.label}</span>
        <span class="room-size">${toMm(item.width)} x ${toMm(item.height)}mm</span>
        <span class="resize-handle" data-resize="true"></span>
      `;
    } else {
      node.innerHTML = `
        <span class="object-symbol">${symbolSvg(item.fixture)}</span>
        <strong>${item.label}</strong>
      `;
      node.querySelector(".object-symbol").style.transform = `rotate(${item.rotation || 0}deg)`;
    }

    node.addEventListener("pointerdown", startObjectDrag);
    canvas.appendChild(node);
  });

  state.lines.forEach((line) => {
    const label = document.createElement("div");
    label.className = "line-label";
    label.style.left = `${(line.x1 + line.x2) / 2}px`;
    label.style.top = `${(line.y1 + line.y2) / 2 - 20}px`;
    label.textContent = `${line.productCode} ${line.lengthMm}mm`;
    label.addEventListener("pointerdown", (event) => {
      event.stopPropagation();
      select(line.id);
    });
    canvas.appendChild(label);
  });
}

function renderLines() {
  lineLayer.innerHTML = "";
  state.lines.forEach((line) => {
    const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
    const hit = document.createElementNS("http://www.w3.org/2000/svg", "line");
    const visual = document.createElementNS("http://www.w3.org/2000/svg", "line");

    [hit, visual].forEach((node) => {
      node.setAttribute("x1", line.x1);
      node.setAttribute("y1", line.y1);
      node.setAttribute("x2", line.x2);
      node.setAttribute("y2", line.y2);
    });

    hit.classList.add("line-hit");
    visual.classList.add("work-line", line.type);
    visual.classList.toggle("selected", line.id === state.selectedId);
    hit.addEventListener("pointerdown", (event) => {
      event.stopPropagation();
      select(line.id);
    });

    group.append(hit, visual);
    lineLayer.appendChild(group);
  });

  if (state.lineDraft) {
    const draft = document.createElementNS("http://www.w3.org/2000/svg", "line");
    draft.setAttribute("x1", state.lineDraft.start.x);
    draft.setAttribute("y1", state.lineDraft.start.y);
    draft.setAttribute("x2", state.lineDraft.end.x);
    draft.setAttribute("y2", state.lineDraft.end.y);
    draft.classList.add("work-line", state.lineDraft.type);
    draft.setAttribute("opacity", "0.55");
    lineLayer.appendChild(draft);
  }
}

function populateProductSelect(selectedType) {
  fields.product.innerHTML = "";
  products
    .filter((product) => !selectedType || product.type === selectedType)
    .forEach((product) => {
      const option = document.createElement("option");
      option.value = product.code;
      option.textContent = `${product.code} ${product.name}`;
      fields.product.appendChild(option);
    });
}

function renderInspector() {
  const selected = getSelected();
  emptyInspector.classList.toggle("hidden", Boolean(selected));
  inspectorForm.classList.toggle("hidden", !selected);

  if (!selected) return;

  const isLine = selected.kind === "line";
  populateProductSelect(isLine ? selected.type : null);

  fields.type.value = isLine ? typeLabel(selected.type) : selected.kind === "room" ? "部屋" : "設備";
  fields.label.value = selected.label || "";
  fields.place.value = selected.place || "";
  fields.product.disabled = !isLine;
  fields.length.disabled = !isLine;
  fields.width.disabled = isLine;
  fields.height.disabled = isLine;
  fields.rotation.disabled = selected.kind !== "fixture";
  fields.quantity.disabled = !isLine;
  fields.unitPrice.disabled = !isLine;
  fields.discount.disabled = !isLine;
  fields.note.disabled = !isLine;
  document.querySelector("#rotateRight").disabled = selected.kind !== "fixture";
  fields.product.value = selected.productCode || "";
  fields.length.value = selected.lengthMm || "";
  fields.width.value = selected.width ? toMm(selected.width) : "";
  fields.height.value = selected.height ? toMm(selected.height) : "";
  fields.rotation.value = selected.rotation || 0;
  fields.quantity.value = selected.quantity || 1;
  fields.unitPrice.value = selected.unitPrice || 0;
  fields.discount.value = selected.discount || 0;
  fields.note.value = selected.note || "";
}

function renderEstimate() {
  const lineItems = state.lines.map((line) => {
    const quantity = Number(line.quantity || 0);
    const unitPrice = Number(line.unitPrice || 0);
    const discount = Number(line.discount || 0);
    return {
      ...line,
      amount: Math.max(0, quantity * unitPrice - discount),
    };
  });

  estimateList.innerHTML = "";
  if (estimatePageList) estimatePageList.innerHTML = "";
  if (!lineItems.length) {
    estimateList.innerHTML = `<div class="empty">施工部材を置くとここに明細が出ます。</div>`;
    if (estimatePageList) estimatePageList.innerHTML = `<div class="empty">図面ページで施工部材を置くとここに明細が出ます。</div>`;
  } else {
    lineItems.forEach((item) => {
      const row = createEstimateRow(item);
      estimateList.appendChild(row);
      if (estimatePageList) estimatePageList.appendChild(createEstimateRow(item));
    });
  }

  const subtotal = lineItems.reduce((sum, item) => sum + item.amount, 0);
  const expenses = ["expenseMisc", "expenseManage", "expenseBase", "expenseDispose", "expenseCarry"].reduce((sum, id) => {
    return sum + Number(document.querySelector(`#${id}`).value || 0);
  }, 0);
  const tax = Math.floor((subtotal + expenses) * 0.1);
  const total = subtotal + expenses + tax;

  document.querySelector("#lineCount").textContent = `${lineItems.length}件`;
  document.querySelector("#subtotal").textContent = money.format(subtotal);
  document.querySelector("#expenseTotal").textContent = money.format(expenses);
  document.querySelector("#tax").textContent = money.format(tax);
  document.querySelector("#grandTotal").textContent = money.format(total);

  if (estimatePageTotals) {
    estimatePageTotals.innerHTML = `
      <div><span>小計</span><strong>${money.format(subtotal)}</strong></div>
      <div><span>経費</span><strong>${money.format(expenses)}</strong></div>
      <div><span>消費税</span><strong>${money.format(tax)}</strong></div>
      <div class="grand"><span>合計</span><strong>${money.format(total)}</strong></div>
    `;
  }
}

function createEstimateRow(item) {
  const row = document.createElement("div");
  row.className = "estimate-row";
  row.innerHTML = `
    <strong>${typeLabel(item.type)} / ${item.place || "場所未設定"}</strong>
    <span>${item.productCode} ${item.productName}</span>
    <span>${item.lengthMm}mm / 数量 ${item.quantity} / ${money.format(item.amount)}</span>
  `;
  row.addEventListener("click", () => {
    setPage("drawing");
    select(item.id);
  });
  return row;
}

function render() {
  applyZoom();
  renderLines();
  renderObjects();
  renderInspector();
  renderEstimate();
  renderProducts();
}

function startObjectDrag(event) {
  event.stopPropagation();
  const node = event.currentTarget;
  const id = node.dataset.id;
  const item = state.objects.find((object) => object.id === id);
  select(id);
  const isResize = event.target.dataset.resize === "true";
  state.drag = {
    id,
    isResize,
    startX: event.clientX,
    startY: event.clientY,
    original: { ...item },
  };
  node.setPointerCapture(event.pointerId);
}

function onPointerMove(event) {
  if (state.drag) {
    const item = state.objects.find((object) => object.id === state.drag.id);
    const dx = (event.clientX - state.drag.startX) / state.zoom;
    const dy = (event.clientY - state.drag.startY) / state.zoom;
    if (state.drag.isResize) {
      item.width = Math.max(gridSize, snap(state.drag.original.width + dx));
      item.height = Math.max(gridSize, snap(state.drag.original.height + dy));
    } else {
      item.x = snap(state.drag.original.x + dx);
      item.y = snap(state.drag.original.y + dy);
    }
    render();
  }

  if (state.lineDraft) {
    state.lineDraft.end = getCanvasPoint(event);
    render();
  }
}

function onPointerUp(event) {
  if (state.drag) state.drag = null;
  if (state.lineDraft) {
    const draft = state.lineDraft;
    state.lineDraft = null;
    if (Math.hypot(draft.end.x - draft.start.x, draft.end.y - draft.start.y) >= gridSize) {
      createLine(draft.type, draft.start, draft.end);
    } else {
      render();
    }
  }
}

function updateSelectedFromForm() {
  const selected = getSelected();
  if (!selected) return;

  selected.label = fields.label.value;
  selected.place = fields.place.value;

  if (selected.kind !== "line") {
    selected.width = Math.max(gridSize, toPx(Number(fields.width.value || mmPerGrid)));
    selected.height = Math.max(gridSize, toPx(Number(fields.height.value || mmPerGrid)));
  }

  if (selected.kind === "fixture") {
    selected.rotation = Number(fields.rotation.value || 0);
  }

  if (selected.kind === "line") {
    const product = products.find((item) => item.code === fields.product.value);
    selected.productCode = fields.product.value;
    selected.productName = product?.name || selected.productName;
    selected.lengthMm = Number(fields.length.value || 0);
    selected.quantity = Number(fields.quantity.value || 0);
    selected.unitPrice = Number(fields.unitPrice.value || 0);
    selected.discount = Number(fields.discount.value || 0);
    selected.note = fields.note.value;
    if (product && document.activeElement === fields.product) {
      selected.unitPrice = product.price;
      fields.unitPrice.value = product.price;
    }
  }
  renderLines();
  renderObjects();
  renderEstimate();
}

function addSample() {
  state.objects = [];
  state.lines = [];
  createRoom("トイレ", 160, 120);
  state.objects.at(-1).width = toPx(900);
  state.objects.at(-1).height = toPx(1800);
  createFixture(fixtures.find((item) => item[0] === "toilet"), 250, 420);
  createFixture(fixtures.find((item) => item[0] === "door"), 390, 760);
  createLine("rail", { x: 200, y: 240 }, { x: 200, y: 520 });
  const rail = state.lines.at(-1);
  rail.place = "トイレ";
  rail.label = "L型手すり";
  rail.productCode = "BD-132";
  rail.productName = products.find((item) => item.code === "BD-132").name;
  rail.quantity = Number((rail.lengthMm / 1000).toFixed(2));
  createLine("step", { x: 560, y: 760 }, { x: 720, y: 760 });
  const step = state.lines.at(-1);
  step.place = "玄関";
  step.productCode = "DS-050";
  step.productName = products.find((item) => item.code === "DS-050").name;
  step.unitPrice = 9800;
  step.quantity = 1;
  select(rail.id);
}

function symbolSvg(type) {
  const stroke = `fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="square" stroke-linejoin="miter"`;
  const soft = `fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="square" stroke-linejoin="miter" opacity=".7"`;
  const symbols = {
    toilet: `
      <svg viewBox="0 0 90 76" aria-hidden="true">
        <rect x="30" y="8" width="30" height="16" ${stroke}/>
        <path d="M26 27h38v20c0 13-9 21-19 21S26 60 26 47z" ${stroke}/>
        <path d="M35 36c7 4 13 4 20 0" ${soft}/>
        <line x1="22" y1="68" x2="68" y2="68" ${soft}/>
      </svg>`,
    kitchen: `
      <svg viewBox="0 0 140 58" aria-hidden="true">
        <rect x="8" y="10" width="124" height="38" ${stroke}/>
        <circle cx="40" cy="29" r="12" ${stroke}/>
        <circle cx="83" cy="29" r="13" ${soft}/>
        <line x1="105" y1="16" x2="126" y2="42" ${soft}/>
        <line x1="126" y1="16" x2="105" y2="42" ${soft}/>
      </svg>`,
    bath: `
      <svg viewBox="0 0 140 86" aria-hidden="true">
        <rect x="12" y="12" width="116" height="62" rx="4" ${stroke}/>
        <rect x="24" y="24" width="92" height="38" rx="8" ${soft}/>
        <circle cx="32" cy="31" r="3" fill="currentColor"/>
        <line x1="18" y1="74" x2="18" y2="82" ${stroke}/>
        <line x1="122" y1="74" x2="122" y2="82" ${stroke}/>
      </svg>`,
    wash: `
      <svg viewBox="0 0 86 72" aria-hidden="true">
        <rect x="15" y="10" width="56" height="46" ${stroke}/>
        <ellipse cx="43" cy="33" rx="22" ry="14" ${soft}/>
        <circle cx="43" cy="26" r="2.8" fill="currentColor"/>
        <line x1="27" y1="62" x2="59" y2="62" ${stroke}/>
      </svg>`,
    door: `
      <svg viewBox="0 0 110 96" aria-hidden="true">
        <line x1="14" y1="82" x2="36" y2="82" ${stroke}/>
        <line x1="78" y1="82" x2="100" y2="82" ${stroke}/>
        <line x1="36" y1="82" x2="36" y2="54" ${stroke}/>
        <path d="M36 54 A46 46 0 0 1 82 82" ${soft}/>
      </svg>`,
    doubleDoor: `
      <svg viewBox="0 0 140 92" aria-hidden="true">
        <line x1="8" y1="78" x2="34" y2="78" ${stroke}/>
        <line x1="106" y1="78" x2="132" y2="78" ${stroke}/>
        <line x1="34" y1="78" x2="34" y2="52" ${stroke}/>
        <line x1="106" y1="78" x2="106" y2="52" ${stroke}/>
        <path d="M34 52 A38 38 0 0 1 70 78" ${soft}/>
        <path d="M106 52 A38 38 0 0 0 70 78" ${soft}/>
      </svg>`,
    sliding: `
      <svg viewBox="0 0 150 46" aria-hidden="true">
        <line x1="6" y1="15" x2="144" y2="15" ${stroke}/>
        <line x1="6" y1="30" x2="144" y2="30" ${stroke}/>
        <rect x="28" y="12" width="48" height="21" ${stroke}/>
        <rect x="80" y="12" width="42" height="21" ${soft}/>
        <line x1="44" y1="8" x2="44" y2="37" ${soft}/>
        <line x1="100" y1="8" x2="100" y2="37" ${soft}/>
      </svg>`,
    folding: `
      <svg viewBox="0 0 140 82" aria-hidden="true">
        <line x1="10" y1="70" x2="34" y2="70" ${stroke}/>
        <line x1="106" y1="70" x2="130" y2="70" ${stroke}/>
        <polyline points="34,70 54,24 74,70 94,24 106,70" ${stroke}/>
        <line x1="34" y1="70" x2="34" y2="54" ${stroke}/>
        <line x1="106" y1="70" x2="106" y2="54" ${stroke}/>
      </svg>`,
    closet: `
      <svg viewBox="0 0 140 56" aria-hidden="true">
        <rect x="8" y="14" width="124" height="28" ${stroke}/>
        <line x1="70" y1="14" x2="70" y2="42" ${soft}/>
        <line x1="46" y1="20" x2="61" y2="20" ${soft}/>
        <line x1="79" y1="20" x2="94" y2="20" ${soft}/>
        <line x1="20" y1="8" x2="120" y2="8" ${soft} stroke-dasharray="5 4"/>
      </svg>`,
    storage: `
      <svg viewBox="0 0 120 64" aria-hidden="true">
        <rect x="12" y="12" width="96" height="42" ${stroke}/>
        <line x1="12" y1="26" x2="108" y2="26" ${soft}/>
        <line x1="36" y1="12" x2="36" y2="54" ${soft}/>
        <line x1="72" y1="12" x2="72" y2="54" ${soft}/>
      </svg>`,
    living: `
      <svg viewBox="0 0 120 64" aria-hidden="true">
        <rect x="16" y="22" width="88" height="26" rx="3" ${stroke}/>
        <rect x="20" y="12" width="22" height="16" rx="2" ${soft}/>
        <rect x="78" y="12" width="22" height="16" rx="2" ${soft}/>
        <line x1="26" y1="52" x2="94" y2="52" ${soft}/>
      </svg>`,
    bedroom: `
      <svg viewBox="0 0 120 66" aria-hidden="true">
        <rect x="16" y="16" width="88" height="38" ${stroke}/>
        <rect x="22" y="22" width="28" height="18" ${soft}/>
        <line x1="54" y1="16" x2="54" y2="54" ${soft}/>
      </svg>`,
    porch: `
      <svg viewBox="0 0 130 58" aria-hidden="true">
        <rect x="12" y="15" width="106" height="28" ${stroke}/>
        <line x1="24" y1="9" x2="106" y2="9" ${soft}/>
        <line x1="24" y1="49" x2="106" y2="49" ${soft}/>
        <line x1="34" y1="15" x2="34" y2="43" ${soft}/>
        <line x1="96" y1="15" x2="96" y2="43" ${soft}/>
      </svg>`,
    parking: `
      <svg viewBox="0 0 150 82" aria-hidden="true">
        <rect x="12" y="12" width="126" height="58" ${stroke}/>
        <path d="M48 58V26h28c12 0 20 6 20 16s-8 16-20 16z" ${soft}/>
        <line x1="48" y1="42" x2="92" y2="42" ${soft}/>
      </svg>`,
  };
  return symbols[type] || `
    <svg viewBox="0 0 120 64" aria-hidden="true">
      <rect x="10" y="12" width="100" height="40" ${stroke}/>
      <line x1="26" y1="22" x2="94" y2="42" ${soft}/>
    </svg>`;
}

function applyZoom() {
  canvas.style.transform = `scale(${state.zoom})`;
  canvasStage.style.width = `${canvasWidth * state.zoom}px`;
  canvasStage.style.height = `${canvasHeight * state.zoom}px`;
  document.querySelector("#zoomLevel").textContent = `${Math.round(state.zoom * 100)}%`;
}

function setZoom(nextZoom) {
  state.zoom = Math.min(2, Math.max(0.4, Number(nextZoom.toFixed(2))));
  applyZoom();
}

function zoomAt(nextZoom, clientX, clientY) {
  const rect = canvas.getBoundingClientRect();
  const before = {
    x: (clientX - rect.left) / state.zoom,
    y: (clientY - rect.top) / state.zoom,
  };
  setZoom(nextZoom);
  canvasWrap.scrollLeft = before.x * state.zoom - (clientX - canvasWrap.getBoundingClientRect().left);
  canvasWrap.scrollTop = before.y * state.zoom - (clientY - canvasWrap.getBoundingClientRect().top);
}

function rotateSelectedFixture() {
  const selected = getSelected();
  if (!selected || selected.kind !== "fixture") return;
  selected.rotation = ((Number(selected.rotation || 0) + 90) % 360 + 360) % 360;
  render();
}

function renderProducts() {
  if (!productTableBody) return;
  productTableBody.innerHTML = "";
  products.forEach((product) => {
    const row = document.createElement("tr");
    row.innerHTML = `
      <td>${product.code}</td>
      <td>${product.name}</td>
      <td>${typeLabel(product.type)}</td>
      <td>${money.format(product.cost)}</td>
      <td>${money.format(product.price)}</td>
      <td>${product.unit}</td>
    `;
    productTableBody.appendChild(row);
  });
}

function setPage(page) {
  document.body.dataset.page = page;
  document.querySelectorAll(".page-tab").forEach((button) => {
    button.classList.toggle("active", button.dataset.pageTarget === page);
  });
  if (page === "estimate") renderEstimate();
  if (page === "products") renderProducts();
}

function addProduct(event) {
  event.preventDefault();
  const code = document.querySelector("#newProductCode").value.trim();
  const name = document.querySelector("#newProductName").value.trim();
  const type = document.querySelector("#newProductType").value;
  const cost = Number(document.querySelector("#newProductCost").value || 0);
  const price = Number(document.querySelector("#newProductPrice").value || 0);
  const unit = document.querySelector("#newProductUnit").value.trim() || "式";

  if (!code || !name) return;
  if (products.some((product) => product.code === code)) {
    window.alert("同じ品番がすでにあります。別の品番を入力してください。");
    return;
  }

  products.push({ code, name, price, cost, unit, type });
  productForm.reset();
  document.querySelector("#newProductType").value = "rail";
  document.querySelector("#newProductCost").value = "0";
  document.querySelector("#newProductPrice").value = "0";
  document.querySelector("#newProductUnit").value = "式";
  renderProducts();
  renderInspector();
}

document.querySelectorAll(".tool").forEach((button) => {
  button.addEventListener("click", () => {
    if (button.dataset.tool === "room") state.roomLabel = button.dataset.label || "部屋";
    setTool(button.dataset.tool);
    if (button.dataset.tool === "room") {
      document.querySelectorAll('.tool[data-tool="room"]').forEach((item) => item.classList.remove("active"));
      button.classList.add("active");
    }
    document.querySelectorAll(".fixture-tool").forEach((item) => item.classList.remove("active"));
  });
});

canvas.addEventListener("pointerdown", (event) => {
  if (event.target !== canvas && event.target !== lineLayer) return;
  const point = getCanvasPoint(event);
  if (state.tool === "room") {
    createRoom(state.roomLabel, point.x, point.y);
  } else if (state.tool.startsWith("fixture:")) {
    const fixture = fixtures.find((item) => item[0] === state.tool.split(":")[1]);
    createFixture(fixture, point.x, point.y);
  } else if (["rail", "slope", "step"].includes(state.tool)) {
    state.lineDraft = { type: state.tool, start: point, end: point };
  } else {
    select(null);
  }
});

window.addEventListener("pointermove", onPointerMove);
window.addEventListener("pointerup", onPointerUp);

Object.values(fields).forEach((field) => {
  field.addEventListener("input", updateSelectedFromForm);
  field.addEventListener("change", updateSelectedFromForm);
});

document.querySelectorAll(".cost-settings input").forEach((input) => input.addEventListener("input", renderEstimate));
document.querySelector("#clearSelection").addEventListener("click", () => select(null));
document.querySelector("#fitDemo").addEventListener("click", addSample);
document.querySelector("#deleteSelected").addEventListener("click", deleteSelected);
document.querySelector("#deleteSelectedInspector").addEventListener("click", deleteSelected);
document.querySelector("#zoomOut").addEventListener("click", () => setZoom(state.zoom - 0.1));
document.querySelector("#zoomIn").addEventListener("click", () => setZoom(state.zoom + 0.1));
document.querySelector("#zoomReset").addEventListener("click", () => setZoom(1));
document.querySelector("#rotateRight").addEventListener("click", rotateSelectedFixture);
productForm.addEventListener("submit", addProduct);

document.querySelectorAll(".page-tab").forEach((button) => {
  button.addEventListener("click", () => setPage(button.dataset.pageTarget));
});

window.addEventListener("keydown", (event) => {
  const tagName = document.activeElement?.tagName;
  const isEditing = ["INPUT", "TEXTAREA", "SELECT"].includes(tagName);
  if (isEditing) return;
  if (event.key === "Delete" || event.key === "Backspace") {
    event.preventDefault();
    deleteSelected();
  }
});

canvasWrap.addEventListener(
  "wheel",
  (event) => {
    if (!event.ctrlKey && !event.metaKey) return;
    event.preventDefault();
    const direction = event.deltaY < 0 ? 1 : -1;
    zoomAt(state.zoom + direction * 0.08, event.clientX, event.clientY);
  },
  { passive: false },
);

let gestureStartZoom = 1;
canvasWrap.addEventListener("gesturestart", (event) => {
  event.preventDefault();
  gestureStartZoom = state.zoom;
});

canvasWrap.addEventListener("gesturechange", (event) => {
  event.preventDefault();
  zoomAt(gestureStartZoom * event.scale, event.clientX, event.clientY);
});

renderFixtures();
addSample();
