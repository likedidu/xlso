const port = process.env.PORT || 3000;
const express = require("express");
const app = express();
var exec = require("child_process").exec;
const { createProxyMiddleware } = require("http-proxy-middleware");

app.get("/", function (req, res) {
  res.send("hello world");
});

//获取系统进程表
app.get("/status", function (req, res) {
  let cmdStr = "pm2 list;ps -ef|grep sing-box";
  exec(cmdStr, function (err, stdout, stderr) {
    if (err) {
      res.type("html").send("<pre>命令行执行错误：\n" + err + "</pre>");
    } else {
      res.type("html").send("<pre>系统进程表：\n" + stdout + "</pre>");
    }
  });
});

app.use(
  "/",
  createProxyMiddleware({
    changeOrigin: true, 
    onProxyReq: function onProxyReq(proxyReq, req, res) { },
    pathRewrite: {
      "^/": "/"
    },
    target: "http://127.0.0.1:63003/", 
    ws: true 
  })
);

exec("bash entrypoint.sh", function (err, stdout, stderr) {
  if (err) {
    console.error(err);
    return;
  }
  console.log(stdout);
});

app.listen(port, () => console.log(`app listening on port ${port}!`));
