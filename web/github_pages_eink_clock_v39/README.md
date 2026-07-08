# DLG-CLOCK Retail Web App

Bản web dùng cho GitHub Pages, dựa trên `eink_control_retail_v39_customer_admin.html`.

## Cách deploy nhanh

### Cách 1: repo thường

1. Tạo repo public, ví dụ: `eink-clock`
2. Upload toàn bộ file trong thư mục này lên root repo:
   - `index.html`
   - `manifest.webmanifest`
   - `service-worker.js`
   - `.nojekyll`
3. Vào repo **Settings → Pages**
4. Source: **Deploy from a branch**
5. Branch: **main**
6. Folder: **/** root
7. Save

Link sẽ có dạng:

```text
https://<github-username>.github.io/eink-clock/
```

### Cách 2: repo tên đặc biệt

Nếu repo tên là:

```text
<github-username>.github.io
```

thì link sẽ là:

```text
https://<github-username>.github.io/
```

## Lưu ý Web Bluetooth

Web Bluetooth cần chạy trên HTTPS. GitHub Pages có HTTPS nên dùng được trên Chrome Android/Desktop.

## Admin

PIN admin mặc định:

```text
585
```

## Bộ nhớ trạng thái

App dùng localStorage theo domain GitHub Pages, ổn định hơn nhiều so với mở file local `content://...`.

Shared storage key:

```text
dlg_clock_commercial_FINAL_v38
```

Nên v38/v39 cùng domain có thể dùng chung trạng thái.
