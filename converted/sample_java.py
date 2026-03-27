import csv
from collections import Counter, OrderedDict

input_file = "inventory_data.csv"
output_file = "inventory_processed.csv"

with open(input_file, 'r', newline='', encoding='utf-8') as f:
    reader = csv.reader(f)
    rows = list(reader)

header = rows[0]
rows = rows[1:]

unique_set = list(OrderedDict.fromkeys(tuple(row) for row in rows))
unique_rows = [list(row) for row in unique_set]

stock_index = 2
price_index = 3

def safe_int(s):
    try:
        return int(s.strip())
    except:
        return 0

def safe_double(s):
    try:
        return float(s.strip())
    except:
        return 0.0

for row in unique_rows:
    row[stock_index] = str(safe_int(row[stock_index]))
    row[price_index] = str(safe_double(row[price_index]))

for row in unique_rows:
    stock = int(row[stock_index])
    reorder_level = stock * 0.3
    target = 1 if stock <= reorder_level else 0
    row.append(f"{reorder_level:.2f}")
    row.append(str(target))

category_index = 1
supplier_index = 4

category_values = [row[category_index] for row in unique_rows]
supplier_values = [row[supplier_index] for row in unique_rows]

def most_frequent(lst):
    count = Counter(lst)
    return count.most_common(1)[0][0]

most_freq_category = most_frequent(category_values)
most_freq_supplier = most_frequent(supplier_values)

for row in unique_rows:
    if not row[category_index].strip():
        row[category_index] = most_freq_category
    if not row[supplier_index].strip():
        row[supplier_index] = most_freq_supplier

unique_categories = list(OrderedDict.fromkeys(category_values))
unique_suppliers = list(OrderedDict.fromkeys(supplier_values))

new_header = list(header) + ["reorder_level", "target"]
for c in unique_categories:
    new_header.append(f"category_{c}")
for s in unique_suppliers:
    new_header.append(f"supplier_{s}")

final_rows = [new_header]

for row in unique_rows:
    encoded = list(row)
    for c in unique_categories:
        encoded.append("1" if row[category_index] == c else "0")
    for s in unique_suppliers:
        encoded.append("1" if row[supplier_index] == s else "0")
    final_rows.append(encoded)

with open(output_file, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerows(final_rows)

print(f"✅ Processing complete. File saved as {output_file}")
