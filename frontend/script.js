const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");

// Initialize canvas
ctx.fillStyle = "white";
ctx.fillRect(0, 0, canvas.width, canvas.height);
ctx.fillStyle = "black";

let drawing = false;
let prev = null;

canvas.onmousedown = (e) => {
  drawing = true;
  prev = { x: e.offsetX, y: e.offsetY };
};

canvas.onmouseup = () => {
  drawing = false;
  prev = null;
};

canvas.onmouseleave = () => {
  drawing = false;
  prev = null;
};

canvas.onmousemove = (e) => {
  if (!drawing || !prev) return;  // ✅ important fix

  ctx.beginPath();
  ctx.moveTo(prev.x, prev.y);
  ctx.lineTo(e.offsetX, e.offsetY);

  ctx.strokeStyle = "black";
  ctx.lineWidth = 4;
  ctx.lineCap = "round";

  ctx.stroke();

  prev = { x: e.offsetX, y: e.offsetY };
};

function predict() {
  const small = document.createElement("canvas");
  small.width = 8;
  small.height = 8;

  const sctx = small.getContext("2d");
  sctx.fillStyle = "white";
  sctx.fillRect(0, 0, 8, 8);

  
const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
const data = imgData.data;

let minX = canvas.width, minY = canvas.height;
let maxX = 0, maxY = 0;

// Find bounding box of drawing
for (let y = 0; y < canvas.height; y++) {
  for (let x = 0; x < canvas.width; x++) {
    const i = (y * canvas.width + x) * 4;
    const val = data[i]; // red channel

    if (val < 200) { // not white
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    }
  }
}

  // Padding
  const padding = 10;
  minX = Math.max(minX - padding, 0);
  minY = Math.max(minY - padding, 0);
  maxX = Math.min(maxX + padding, canvas.width);
  maxY = Math.min(maxY + padding, canvas.height);
  sctx.filter = "blur(0.5px)";
  // Draw cropped and centered
  sctx.drawImage(
    canvas,
    minX, minY, maxX - minX, maxY - minY,
    0, 0, 8, 8
  );


  const smallData = sctx.getImageData(0, 0, 8, 8).data;
const pixels = [];

for (let i = 0; i < smallData.length; i += 4) {
const r = smallData[i], g = smallData[i+1], b = smallData[i+2];
    
    const gray = (r + g + b) / 3 / 255;
    const v = (1 - gray) * 16;
    pixels.push(Number(v.toFixed(2)));

  }

  console.log(pixels);
  console.log("sum:", pixels.reduce((a, b) => a + b, 0));

  fetch("/api/predict?ts=" + Date.now(), {
    method: "POST",
    cache: "no-store",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ pixels })
  })
  .then(res => res.json())
  .then(d => {
    document.getElementById("result").innerText = d.prediction || JSON.stringify(d);
  });
}

function clearCanvas() {
  ctx.fillStyle = "white";
ctx.fillRect(0, 0, canvas.width, canvas.height);
ctx.strokeStyle = "black";
}