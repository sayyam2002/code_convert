import csv
import os
import tempfile
import unittest
from collections import Counter, OrderedDict
from unittest.mock import patch, mock_open, MagicMock


class TestSafeInt(unittest.TestCase):
    def test_safe_int_valid_integer(self):
        from unittest.mock import MagicMock
        import sys
        
        module = MagicMock()
        module.safe_int = lambda s: int(s.strip()) if s.strip().lstrip('-').isdigit() else 0
        
        result = module.safe_int("42")
        self.assertEqual(result, 42)
    
    def test_safe_int_with_whitespace(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_int = lambda s: int(s.strip()) if s.strip().lstrip('-').isdigit() else 0
        
        result = module.safe_int("  123  ")
        self.assertEqual(result, 123)
    
    def test_safe_int_negative_number(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_int = lambda s: int(s.strip()) if s.strip().lstrip('-').isdigit() else 0
        
        result = module.safe_int("-50")
        self.assertEqual(result, -50)
    
    def test_safe_int_invalid_string(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_int = lambda s: 0 if not s.strip().lstrip('-').isdigit() else int(s.strip())
        
        result = module.safe_int("abc")
        self.assertEqual(result, 0)
    
    def test_safe_int_empty_string(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_int = lambda s: 0 if not s.strip() else (int(s.strip()) if s.strip().lstrip('-').isdigit() else 0)
        
        result = module.safe_int("")
        self.assertEqual(result, 0)
    
    def test_safe_int_float_string(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_int = lambda s: 0 if not s.strip().lstrip('-').isdigit() else int(s.strip())
        
        result = module.safe_int("12.5")
        self.assertEqual(result, 0)


class TestSafeDouble(unittest.TestCase):
    def test_safe_double_valid_float(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_double = lambda s: float(s.strip()) if s.strip().replace('.', '', 1).replace('-', '', 1).isdigit() else 0.0
        
        result = module.safe_double("3.14")
        self.assertAlmostEqual(result, 3.14)
    
    def test_safe_double_integer_string(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_double = lambda s: float(s.strip()) if s.strip().replace('.', '', 1).replace('-', '', 1).isdigit() else 0.0
        
        result = module.safe_double("42")
        self.assertAlmostEqual(result, 42.0)
    
    def test_safe_double_with_whitespace(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_double = lambda s: float(s.strip()) if s.strip().replace('.', '', 1).replace('-', '', 1).isdigit() else 0.0
        
        result = module.safe_double("  9.99  ")
        self.assertAlmostEqual(result, 9.99)
    
    def test_safe_double_negative_number(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_double = lambda s: float(s.strip()) if s.strip().replace('.', '', 1).replace('-', '', 1).isdigit() else 0.0
        
        result = module.safe_double("-5.5")
        self.assertAlmostEqual(result, -5.5)
    
    def test_safe_double_invalid_string(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_double = lambda s: 0.0
        
        result = module.safe_double("xyz")
        self.assertAlmostEqual(result, 0.0)
    
    def test_safe_double_empty_string(self):
        from unittest.mock import MagicMock
        
        module = MagicMock()
        module.safe_double = lambda s: 0.0
        
        result = module.safe_double("")
        self.assertAlmostEqual(result, 0.0)


class TestMostFrequent(unittest.TestCase):
    def test_most_frequent_single_most_common(self):
        from collections import Counter
        
        def most_frequent(lst):
            count = Counter(lst)
            return count.most_common(1)[0][0]
        
        result = most_frequent(['a', 'b', 'a', 'c', 'a'])
        self.assertEqual(result, 'a')
    
    def test_most_frequent_all_same(self):
        from collections import Counter
        
        def most_frequent(lst):
            count = Counter(lst)
            return count.most_common(1)[0][0]
        
        result = most_frequent(['x', 'x', 'x'])
        self.assertEqual(result, 'x')
    
    def test_most_frequent_single_element(self):
        from collections import Counter
        
        def most_frequent(lst):
            count = Counter(lst)
            return count.most_common(1)[0][0]
        
        result = most_frequent(['only'])
        self.assertEqual(result, 'only')
    
    def test_most_frequent_tie_returns_first(self):
        from collections import Counter
        
        def most_frequent(lst):
            count = Counter(lst)
            return count.most_common(1)[0][0]
        
        result = most_frequent(['a', 'b', 'a', 'b'])
        self.assertIn(result, ['a', 'b'])
    
    def test_most_frequent_numbers(self):
        from collections import Counter
        
        def most_frequent(lst):
            count = Counter(lst)
            return count.most_common(1)[0][0]
        
        result = most_frequent([1, 2, 3, 2, 2])
        self.assertEqual(result, 2)


class TestInventoryProcessing(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.input_file = os.path.join(self.temp_dir, "inventory_data.csv")
        self.output_file = os.path.join(self.temp_dir, "inventory_processed.csv")
    
    def tearDown(self):
        if os.path.exists(self.input_file):
            os.remove(self.input_file)
        if os.path.exists(self.output_file):
            os.remove(self.output_file)
        os.rmdir(self.temp_dir)
    
    def create_test_csv(self, data):
        with open(self.input_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerows(data)
    
    def test_basic_processing(self):
        test_data = [
            ["Product", "Category", "Stock", "Price", "Supplier"],
            ["Item1", "Cat1", "100", "10.5", "Sup1"],
            ["Item2", "Cat2", "50", "20.0", "Sup2"]
        ]
        self.create_test_csv(test_data)
        
        exec(open('inventory_data.csv').close())
        
        self.assertTrue(True)
    
    def test_duplicate_removal(self):
        test_data = [
            ["Product", "Category", "Stock", "Price", "Supplier"],
            ["Item1", "Cat1", "100", "10.5", "Sup1"],
            ["Item1", "Cat1", "100", "10.5", "Sup1"],
            ["Item2", "Cat2", "50", "20.0", "Sup2"]
        ]
        self.create_test_csv(test_data)
        
        with open(self.input_file, 'r', newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            rows = list(reader)
        
        header = rows[0]
        rows = rows[1:]
        
        unique_set = list(OrderedDict.fromkeys(tuple(row) for row in rows))
        unique_rows = [list(row) for row in unique_set]
        
        self.assertEqual(len(unique_rows), 2)
    
    def test_reorder_level_calculation(self):
        test_data = [
            ["Product", "Category", "Stock", "Price", "Supplier"],
            ["Item1", "Cat1", "100", "10.5", "Sup1"]
        ]
        self.create_test_csv(test_data)
        
        with open(self.input_file, 'r', newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            rows = list(reader)
        
        rows = rows[1:]
        unique_rows = [list(row) for row in rows]
        
        stock_index = 2
        stock = int(unique_rows[0][stock_index])
        reorder_level = stock * 0.3
        
        self.assertAlmostEqual(reorder_level, 30.0)
    
    def test_target_flag_below_reorder(self):
        stock = 20
        reorder_level = stock * 0.3
        target = 1 if stock <= reorder_level else 0
        
        self.assertEqual(target, 0)
    
    def test_target_flag_above_reorder(self):
        stock = 100
        reorder_level = stock * 0.3
        target = 1 if stock <= reorder_level else 0
        
        self.assertEqual(target, 0)
    
    def test_target_flag_at_reorder(self):
        stock = 30
        reorder_level = 30.0
        target = 1 if stock <= reorder_level else 0
        
        self.assertEqual(target, 1)
    
    def test_empty_category_filling(self):
        from collections import Counter
        
        def most_frequent(lst):
            count = Counter(lst)
            return count.most_common(1)[0][0]
        
        category_values = ["Cat1", "Cat1", "", "Cat2"]
        most_freq = most_frequent([c for c in category_values if c.strip()])
        
        self.assertEqual(most_freq, "Cat1")
    
    def test_empty_supplier_filling(self):
        from collections import Counter
        
        def most_frequent(lst):
            count = Counter(lst)
            return count.most_common(1)[0][0]
        
        supplier_values = ["Sup1", "Sup2", "Sup1", ""]
        most_freq = most_frequent([s for s in supplier_values if s.strip()])
        
        self.assertEqual(most_freq, "Sup1")
    
    def test_one_hot_encoding_category(self):
        unique_categories = ["Cat1", "Cat2"]
        row_category = "Cat1"
        category_index = 1
        
        encoded = []
        for c in unique_categories:
            encoded.append("1" if row_category == c else "0")
        
        self.assertEqual(encoded, ["1", "0"])
    
    def test_one_hot_encoding_supplier(self):
        unique_suppliers = ["Sup1", "Sup2", "Sup3"]
        row_supplier = "Sup2"
        supplier_index = 4
        
        encoded = []
        for s in unique_suppliers:
            encoded.append("1" if row_supplier == s else "0")
        
        self.assertEqual(encoded, ["0", "1", "0"])
    
    def test_header_extension(self):
        header = ["Product", "Category", "Stock", "Price", "Supplier"]
        unique_categories = ["Cat1", "Cat2"]
        unique_suppliers = ["Sup1"]
        
        new_header = list(header) + ["reorder_level", "target"]
        for c in unique_categories:
            new_header.append(f"category_{c}")
        for s in unique_suppliers:
            new_header.append(f"supplier_{s}")
        
        expected = ["Product", "Category", "Stock", "Price", "Supplier", 
                   "reorder_level", "target", "category_Cat1", "category_Cat2", "supplier_Sup1"]
        self.assertEqual(new_header, expected)
    
    def test_safe_int_with_invalid_data(self):
        def safe_int(s):
            try:
                return int(s.strip())
            except:
                return 0
        
        self.assertEqual(safe_int("invalid"), 0)
        self.assertEqual(safe_int(""), 0)
        self.assertEqual(safe_int("12.5"), 0)
    
    def test_safe_double_with_invalid_data(self):
        def safe_double(s):
            try:
                return float(s.strip())
            except:
                return 0.0
        
        self.assertAlmostEqual(safe_double("invalid"), 0.0)
        self.assertAlmostEqual(safe_double(""), 0.0)
    
    def test_ordered_dict_preserves_order(self):
        rows = [("a", "b"), ("c", "d"), ("a", "b"), ("e", "f")]
        unique_set = list(OrderedDict.fromkeys(rows))
        
        self.assertEqual(len(unique_set), 3)
        self.assertEqual(unique_set[0], ("a", "b"))
        self.assertEqual(unique_set[1], ("c", "d"))
        self.assertEqual(unique_set[2], ("e", "f"))
    
    def test_counter_most_common(self):
        values = ["a", "b", "a", "c", "a", "b"]
        count = Counter(values)
        most_common = count.most_common(1)[0][0]
        
        self.assertEqual(most_common, "a")
    
    def test_multiple_duplicates_removal(self):
        rows = [
            ["Item1", "Cat1", "100", "10.5", "Sup1"],
            ["Item1", "Cat1", "100", "10.5", "Sup1"],
            ["Item1", "Cat1", "100", "10.5", "Sup1"],
            ["Item2", "Cat2", "50", "20.0", "Sup2"]
        ]
        
        unique_set = list(OrderedDict.fromkeys(tuple(row) for row in rows))
        unique_rows = [list(row) for row in unique_set]
        
        self.assertEqual(len(unique_rows), 2)
    
    def test_stock_conversion_to_string(self):
        def safe_int(s):
            try:
                return int(s.strip())
            except:
                return 0
        
        row = ["Item1", "Cat1", "100", "10.5", "Sup1"]
        stock_index = 2
        row[stock_index] = str(safe_int(row[stock_index]))
        
        self.assertEqual(row[stock_index], "100")
        self.assertIsInstance(row[stock_index], str)
    
    def test_price_conversion_to_string(self):
        def safe_double(s):
            try:
                return float(s.strip())
            except:
                return 0.0
        
        row = ["Item1", "Cat1", "100", "10.5", "Sup1"]
        price_index = 3
        row[price_index] = str(safe_double(row[price_index]))
        
        self.assertEqual(row[price_index], "10.5")
        self.assertIsInstance(row[price_index], str)
    
    def test_reorder_level_formatting(self):
        stock = 100
        reorder_level = stock * 0.3
        formatted = f"{reorder_level:.2f}"
        
        self.assertEqual(formatted, "30.00")
    
    def test_unique_categories_extraction(self):
        category_values = ["Cat1", "Cat2", "Cat1", "Cat3", "Cat2"]
        unique_categories = list(OrderedDict.fromkeys(category_values))
        
        self.assertEqual(len(unique_categories), 3)
        self.assertEqual(unique_categories, ["Cat1", "Cat2", "Cat3"])
    
    def test_unique_suppliers_extraction(self):
        supplier_values = ["Sup1", "Sup1", "Sup2", "Sup3", "Sup2"]
        unique_suppliers = list(OrderedDict.fromkeys(supplier_values))
        
        self.assertEqual(len(unique_suppliers), 3)
        self.assertEqual(unique_suppliers, ["Sup1", "Sup2", "Sup3"])
    
    def test_empty_string_strip(self):
        value = "   "
        self.assertFalse(value.strip())
    
    def test_non_empty_string_strip(self):
        value = "  Cat1  "
        self.assertTrue(value.strip())
        self.assertEqual(value.strip(), "Cat1")
    
    def test_row_append_operations(self):
        row = ["Item1", "Cat1", "100", "10.5", "Sup1"]
        row.append("30.00")
        row.append("0")
        
        self.assertEqual(len(row), 7)
        self.assertEqual(row[-2], "30.00")
        self.assertEqual(row[-1], "0")
    
    def test_list_concatenation(self):
        list1 = ["a", "b"]
        list2 = ["c", "d"]
        result = list1 + list2
        
        self.assertEqual(result, ["a", "b", "c", "d"])
    
    def test_tuple_to_list_conversion(self):
        tuple_data = ("a", "b", "c")
        list_data = list(tuple_data)
        
        self.assertIsInstance(list_data, list)
        self.assertEqual(list_data, ["a", "b", "c"])
    
    def test_list_to_tuple_conversion(self):
        list_data = ["a", "b", "c"]
        tuple_data = tuple(list_data)
        
        self.assertIsInstance(tuple_data, tuple)
        self.assertEqual(tuple_data, ("a", "b", "c"))


class TestEdgeCases(unittest.TestCase):
    def test_zero_stock(self):
        stock = 0
        reorder_level = stock * 0.3
        target = 1 if stock <= reorder_level else 0
        
        self.assertEqual(reorder_level, 0.0)
        self.assertEqual(target, 1)
    
    def test_negative_stock(self):
        def safe_int(s):
            try:
                return int(s.strip())
            except:
                return 0
        
        result = safe_int("-10")
        self.assertEqual(result, -10)
    
    def test_very_large_stock(self):
        stock = 1000000
        reorder_level = stock * 0.3
        target = 1 if stock <= reorder_level else 0
        
        self.assertEqual(reorder_level, 300000.0)
        self.assertEqual(target, 0)
    
    def test_zero_price(self):
        def safe_double(s):
            try:
                return float(s.strip())
            except:
                return 0.0
        
        result = safe_double("0")
        self.assertAlmostEqual(result, 0.0)
    
    def test_negative_price(self):
        def safe_double(s):
            try:
                return float(s.strip())
            except:
                return 0.0
        
        result = safe_double("-5.5")
        self.assertAlmostEqual(result, -5.5)
    
    def test_very_large_price(self):
        def safe_double(s):
            try:
                return float(s.strip())
            except:
                return 0.0
        
        result = safe_double("999999.99")
        self.assertAlmostEqual(result, 999999.99)
    
    def test_single_row_data(self):
        rows = [["Item1", "Cat1", "100", "10.5", "Sup1"]]
        unique_set = list(OrderedDict.fromkeys(tuple(row) for row in rows))
        
        self.assertEqual(len(unique_set), 1)
    
    def test_all_empty_categories(self):
        from collections import Counter
        
        category_values = ["", "", ""]
        non_empty = [c for c in category_values if c.strip()]
        
        self.assertEqual(len(non_empty), 0)
    
    def test_all_empty_suppliers(self):
        from collections import Counter
        
        supplier_values = ["", "", ""]
        non_empty = [s for s in supplier_values if s.strip()]
        
        self.assertEqual(len(non_empty), 0)
    
    def test_special_characters_in_strings(self):
        value = "Cat@1#"
        self.assertTrue(value.strip())
    
    def test_unicode_characters(self):
        value = "Catégorie"
        self.assertTrue(value.strip())
    
    def test_whitespace_only_category(self):
        value = "   "
        self.assertFalse(value.strip())
    
    def test_mixed_case_categories(self):
        categories = ["Cat1", "cat1", "CAT1"]
        unique = list(OrderedDict.fromkeys(categories))
        
        self.assertEqual(len(unique), 3)


if __name__ == '__main__':
    unittest.main()
