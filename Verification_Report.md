# Báo cáo xác minh RISC-V 32-bit · Giai đoạn 4

**Ngày chạy 13/11/2026.** DUT là `Processor/PROCESSOR.v` với chín lệnh ADD, SUB, MUL, SLL, SRL, XOR, OR, AND và SLT. Môi trường dùng QuestaSim-64 10.7c, UVM 1.2 và SVA. Phạm vi nghiệm thu gồm các khối RTL độc lập và đường thực thi từ fetch đến writeback. [Kế hoạch xác minh](../../RISC-V_Verification_Plan.xlsx)

## Kết quả nghiệm thu kỹ thuật

| Tiêu chí | Kết quả | Ngưỡng |
|---|---:|---:|
| Ma trận chính | 41/41 PASS, gồm 27 P1 và 14 P2 | 100% |
| Toàn bộ lượt mô phỏng | 55/55 PASS | 0 lỗi |
| Lệnh constrained-random so khớp | 10.000, trên 10 seed | ≥10.000 |
| Scoreboard và kiểm tra mức chân | 10.550/10.550 lệnh so khớp, 355 kỳ vọng mức chân đạt | 0 sai lệch |
| Functional coverage | 518/518 bin thuộc 16 mục trong kế hoạch | 100% |
| Statement | 69/69 | 100% |
| Branch | 25/25 | ≥95% |
| Condition / Expression (FEC) | 3/3 và 1/1 | ≥95% mỗi loại |
| Toggle, số bit đã chuyển cả hai chiều | 1.731/1.839 = 94,13% | ≥90% |
| Assertion của dự án | 141/141 instance có lượt PASS, 0 vi phạm | 0 vi phạm |
| Lỗi RTL P1/P2 đã biết còn mở trong phạm vi | 0 | 0 |

Mã trả về và cổng kiểm tra tự động ghi nhận kết quả nghiệm thu. Có một UCDB cho mỗi lượt chạy và một UCDB gộp. [Kết quả nghiệm thu](seed_12345_n1000_20261113_114006_22344/signoff.txt) · [Danh sách 55 lượt chạy và đường dẫn log](seed_12345_n1000_20261113_114006_22344/summary.txt) · [UCDB gộp](seed_12345_n1000_20261113_114006_22344/merged.ucdb)

Ở lượt trung gian, cả 48 mô phỏng đều PASS và các ngưỡng coverage đều đạt. Cổng nghiệm thu vẫn trả FAIL vì mới kiểm 3.000 giao dịch ngẫu nhiên. Lượt cuối cùng dùng 10 seed độc lập để đạt mức 10.000 giao dịch cam kết trong chiến lược UVM. [Kết quả lượt trung gian](seed_12345_n1000_20261113_113855_22524/signoff.txt)

## Hồi quy và đối chiếu với golden model

- Ma trận sử dụng seed 12345. Chín lượt bổ sung của `TC_CORE_05` mở rộng đến seed 12354. Mỗi seed chạy 1.000 lệnh R-type hợp lệ. ROM vật lý có tám từ lệnh nên driver chia mỗi lượt thành 125 chương trình, mỗi chương trình có reset và khởi tạo toán hạng riêng.
- Ba bài kiểm tra tương thích chạy ROM mặc định, chương trình smoke có phụ thuộc RAW và ROM lặp qua ba lần reset. Scoreboard lần lượt khớp 8/8, 4/4 và 24/24 lệnh. [Log ROM](seed_12345_n1000_20261113_114006_22344/logs/riscv_base_test_s12345.log) · [Log smoke](seed_12345_n1000_20261113_114006_22344/logs/riscv_program_smoke_test_s12345.log) · [Log ba lần reset](seed_12345_n1000_20261113_114006_22344/logs/riscv_full_test_s12345.log)
- Bài đóng coverage chạy 410 lệnh trên 59 chương trình ngắn để kiểm tra các tổ hợp đích, cờ zero, toán hạng biên và RAW. Bài kiểm tra bộ giải mã chạy 80 lệnh trên 10 chương trình. Scoreboard xác nhận 40 lệnh không hỗ trợ bị chặn ghi. SVA đối chiếu cả 32 thanh ghi qua cạnh clock khi write-enable bằng 0. [Log đóng coverage](seed_12345_n1000_20261113_114006_22344/logs/riscv_coverage_closure_test_s12345.log) · [Log giải mã](seed_12345_n1000_20261113_114006_22344/logs/riscv_invalid_decode_test_s12345.log) · [Báo cáo SVA](seed_12345_n1000_20261113_114006_22344/assertions.txt)

## Lỗi RTL và bằng chứng tái kiểm

Giai đoạn 3 có 32/41 ca PASS. Riêng `TC_CORE_05` sai 418/1.000 lệnh ở seed 12345. Nhiều lỗi xuất hiện trong cùng một ca tích hợp. Bảng dưới ghi theo nguyên nhân để tránh đếm trùng ca FAIL. Các bản RTL dùng cho unit bench riêng cũng đã được đồng bộ. [Baseline](../phase3/seed_12345_n1000/summary.txt) · [Stress trước khi sửa](../phase3/seed_12345_n1000/TC_CORE_05.log) · [Cùng seed sau sửa](seed_12345_n1000_20261113_114006_22344/logs/TC_CORE_05_s12345.log)

| Hiện tượng trước sửa | Sửa RTL | Ca xác nhận PASS |
|---|---|---|
| ROM tại PC 0x08 thực thi MUL như SUB, trả 0xFFFFFFFF thay vì 0x420. SLT bị ánh xạ sang MUL. | CONTROL giải mã đầy đủ opcode, funct7 và funct3 cho cả chín lệnh. | TC_CTRL_03, TC_CORE_01, TC_CORE_05 |
| Sau một lệnh hợp lệ, opcode hoặc funct không hỗ trợ vẫn cho phép ghi. | Nhánh mặc định hạ write-enable và xác định giá trị điều khiển ALU. | TC_CTRL_04, TC_CTRL_05, riscv_invalid_decode_test |
| Dịch 32 bit cho kết quả 0. SLL của ROM ở PC 0x10 trả 0 thay vì 0x480. | SLL/SRL dùng năm bit thấp của toán hạng dịch. | TC_ALU_11, TC_CORE_01, TC_CORE_05 |
| SLT cho 0 khi so sánh 0xFFFFFFFF với 1. | ALU so sánh hai toán hạng 32-bit có dấu. Nhánh điều khiển ALU ngoài tập hỗ trợ có đầu ra xác định. | TC_ALU_14, TC_ALU_01 |
| x0 nhận 0xDEADBEEF. Khi giữ reset, x6 bị ghi thành 0x11 trước khi chạy lệnh đầu tiên. | Register file ưu tiên reset bất đồng bộ, ghi nonblocking tại cạnh lên và chặn đích x0. Giữ ảnh reset của dự án, gồm x10=0x10. | TC_REG_04, TC_SAN_01, TC_REG_07 |

ROM nạp lại chương trình gốc tại cạnh lên của reset. Mô tả cạnh này thay cho `always @(reset)` với điều kiện `if (reset)` dư thừa. Các ca reset, fetch little-endian và chạy chương trình nạp sau reset đều đã được tái kiểm. [RTL bộ nhớ lệnh](../../Processor/INST_MEM.v) · [Log fetch](seed_12345_n1000_20261113_114006_22344/logs/TC_IFU_03_s12345.log)

## Cách đọc coverage và giới hạn

Functional coverage gộp quan sát từ chân decoder/IFU và monitor của core. Các cross đạt 288/288 tổ hợp lệnh × rd, 18/18 lệnh × zero, 36/36 cặp toán hạng biên và 32/32 địa chỉ producer–consumer. Với x1…x31, lệnh sau đọc dữ liệu từ thanh ghi đích của lệnh trước. Với x0, địa chỉ trùng nhưng giá trị vẫn bằng 0 do ghi bị bỏ. Giá trị −1 có bin riêng, còn bin số âm nhỏ dùng −100…−2. [Các bin và số hit](seed_12345_n1000_20261113_114006_22344/functional.txt)

Code coverage được tính theo **định nghĩa RTL**, gộp hit từ instance của cùng module ở unit và core. Bảy design unit được biên dịch với `+cover=bcesft`. Mảng register file và instruction memory đều bật đo toggle. Tổng cộng có 3.464/3.678 hướng chuyển đã xảy ra (94,18%). Khi yêu cầu từng bit phải thấy cả 0→1 và 1→0, tỷ lệ là 94,13%. Không áp dụng waiver thủ công. DATAPATH và PROCESSOR chủ yếu nối dây, Questa không sinh statement bin cho hai module này. Thiết kế không có FSM cần đo. [Theo design unit](seed_12345_n1000_20261113_114006_22344/code_by_design_unit.txt) · [Theo file và instance](seed_12345_n1000_20261113_114006_22344/code_totals.txt)

Khi tính từng instance riêng, Questa ghi nhận 137/138 statement. Nhánh mặc định của ALU được kích thích trực tiếp ở unit bench. Bộ giải mã core chỉ phát chín mã ALU đã định nghĩa, kể cả khi xử lý từ lệnh không hỗ trợ bằng cách hạ write-enable. [Kiểm tra unit ALU](seed_12345_n1000_20261113_114006_22344/logs/TC_ALU_01_s12345.log)

IFU riêng đạt 89/132 hướng toggle (67,42%). Các bit PC[1:0] cố định do căn hàng bốn byte, còn PC[31:12] chưa thể hiện đủ hai chiều trong các lượt chạy. Danh sách thiếu cũng ghi nhận x0 và biến vòng lặp reset của register file. Các bin này vẫn nằm trong mẫu số. Ngưỡng 90% áp dụng trên toàn thiết kế. [Chi tiết bin chưa đạt](seed_12345_n1000_20261113_114006_22344/code_details.txt)

`TC_IFU_05` quan sát được từ lệnh X khi PC bằng 32 và 36, đúng tiêu chí đặc tả hành vi ngoài ROM. Kết quả nghiệm thu áp dụng cho chương trình nằm trong tám từ lệnh và chín phép toán đã nêu. Các chương trình dài liên tục, trap/CSR và phần còn lại của ISA nằm ngoài phạm vi. [Log biên ROM](seed_12345_n1000_20261113_114006_22344/logs/TC_IFU_05_s12345.log)

## Chạy lại

Từ thư mục gốc của dự án, chạy trong PowerShell với giấy phép Questa và thư viện UVM 1.2 của bản cài đặt.

```powershell
& 'C:/questasim64_10.7c/win64/vsim.exe' -c -do "do sim/run.do phase4 12345 1000"
```

Mỗi lần chạy tạo một thư mục mới dưới `sim/phase4`. Runner kiểm tra trạng thái kết thúc UVM, gộp đúng các UCDB của lượt hiện tại, kiểm tra các ngưỡng và trả mã khác 0 khi một tiêu chí không đạt. Để debug lại riêng ca stress, dùng `do sim/run.do TC_CORE_05 12345 1000` trong Questa. [Script hồi quy](../run.do) · [Script kiểm tra kết quả](../phase4_report.tcl) · [SHA-256 của mã nguồn dùng cho lần nghiệm thu](seed_12345_n1000_20261113_114006_22344/sources.sha256)
