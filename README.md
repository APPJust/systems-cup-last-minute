# 系際盃：最後一分鐘

一款以「系際盃籃球決賽」為主題的 Godot 4 網頁物理投籃遊戲。主角是資通系 23 號球員「阿籃」。遊戲共三節、每節 20 秒；每一節達成指定分數才能晉級。

首頁署名：**資通系 李振偉老師**

## 操作與規則

- 電腦：滑鼠按住左側籃球，往左下拖曳調整方向與力道，放開投籃。
- 手機／平板：觸碰並拖曳籃球，往左下拉後放手。建議橫向遊玩。
- 一般進球得 2 分；球從籃框中央穿過時為空心球，得 3 分。
- 每節 20 秒。第一節目標 4 分、第二節 6 分、第三節 8 分；任何一節時間到仍未達標即比賽失敗。
- 第一節籃框固定；第二節開始左右移動；第三節移動幅度加大，並加入風向干擾。
- 比賽結束會顯示總分、命中數、未進球數與最長連中，並提供重玩或回首頁。

## 開發與匯出

使用 Godot 4.7.2 標準版與 GDScript。Web 匯出關閉執行緒，減少網頁伺服器隔離標頭需求；網頁使用 Godot Compatibility renderer。

```powershell
python tools/generate_audio.py
godot --headless --path . --editor --quit
godot --headless --path . --export-release Web web/index.html
```

輸出在 `web/`。可用本機 HTTP 伺服器預覽，例如：

```powershell
python -m http.server 8000 --directory web
```

然後開啟 `http://localhost:8000`。直接以 `file://` 開啟匯出頁面不受支援。

## GitHub Pages

正式遊玩網址：[系際盃：最後一分鐘](https://appjust.github.io/systems-cup-last-minute/)。

`.github/workflows/deploy.yml` 會在推送 `main` 分支或手動執行時部署 `web/`；本 repository 的 Pages 來源已設為 **GitHub Actions**。若複製到其他 repository，請在 **Settings → Pages** 選擇 **GitHub Actions**。

## 素材與授權

- 場館、角色、球場、介面與圖示皆由 GDScript 原創繪製，沒有外部圖片素材。
- 投籃、進球、失手與終場音效由 `tools/generate_audio.py` 程式合成，沒有外部音樂素材。
- 中文字型使用 Google Fonts 的 **Noto Sans TC**，依 SIL Open Font License 1.1 提供；授權全文在 `assets/fonts/OFL.txt`。首頁亦標示字型來源。

署名：資通系 李振偉老師
