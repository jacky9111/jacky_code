學位考試申請 — doc/ 資料夾說明
================================

【一鍵編譯 — 學位考試申請（含附件）】
  .\build_degree_exam.ps1
輸出：degree_exam_submit.pdf

【一鍵編譯 — 論文（封面＋內頁＋內文）】
  .\build_thesis_only.ps1
輸出：胡嘉祐_113522011.pdf
內容：doc/01_封面.pdf + doc/02_title_page.pdf + 論文內文（無致謝、無申請附件）

【合併順序】
  doc/01_封面.pdf
  thesis_02_title.pdf              正式內頁
  doc/03_指導教授推薦函.pdf
  doc/學生論文比對結果報告書.pdf    第 4 頁
  doc/04_論文比對電子回條.pdf
  doc/05_系所規定審核文件.pdf      → 中文摘要前
  thesis_03_content.pdf            論文內文（無致謝）

【可選】thesis_01_cover.tex 僅供 LaTeX 草稿封面，正式封面以 doc/01_封面.pdf 為準。
