/// Markdown Generation Tests
/// 
/// Tests the markdown output format and content
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ja');
  });

  group('Date Formatting', () {
    test('should format date in Japanese style', () {
      final date = DateTime(2024, 12, 12);
      final formatted = DateFormat('yyyy年M月d日 (E)', 'ja').format(date);
      
      expect(formatted, contains('2024年12月12日'));
    });

    test('should format time correctly', () {
      final time = DateTime(2024, 12, 12, 15, 30);
      final formatted = DateFormat('HH:mm').format(time);
      
      expect(formatted, '15:30');
    });

    test('should format date for filename', () {
      final date = DateTime(2024, 12, 5);
      final day = date.day.toString().padLeft(2, '0');
      
      expect(day, '05');
    });
  });

  group('Obsidian Link Format', () {
    test('should generate correct wiki-link syntax', () {
      String obsidianLink(String title, String path) {
        return '[[$path|$title]]';
      }

      final link = obsidianLink('12月12日', '2024/12/12');
      expect(link, '[[2024/12/12|12月12日]]');
    });

    test('should handle paths with multiple levels', () {
      String obsidianLink(String title, String path) {
        return '[[$path|$title]]';
      }

      final link = obsidianLink('1月', '2024/01/2024-01');
      expect(link, '[[2024/01/2024-01|1月]]');
    });
  });

  group('Week Number Calculation', () {
    int getWeekNumber(DateTime date) {
      final firstDayOfYear = DateTime(date.year, 1, 1);
      final daysDiff = date.difference(firstDayOfYear).inDays;
      return ((daysDiff + firstDayOfYear.weekday - 1) / 7).ceil();
    }

    test('should calculate week 1 for early January', () {
      final date = DateTime(2024, 1, 3);
      expect(getWeekNumber(date), 1);
    });

    test('should calculate week 50 for mid December', () {
      final date = DateTime(2024, 12, 12);
      final week = getWeekNumber(date);
      expect(week, greaterThanOrEqualTo(49));
      expect(week, lessThanOrEqualTo(51));
    });

    test('should calculate week 52 for late December', () {
      final date = DateTime(2024, 12, 28);
      final week = getWeekNumber(date);
      expect(week, greaterThanOrEqualTo(51));
    });
  });

  group('Directory Structure', () {
    test('should generate correct year folder name', () {
      final date = DateTime(2024, 12, 12);
      expect(date.year.toString(), '2024');
    });

    test('should generate correct month folder name with padding', () {
      final date = DateTime(2024, 3, 12);
      final month = date.month.toString().padLeft(2, '0');
      expect(month, '03');
    });

    test('should generate correct daily file name', () {
      final date = DateTime(2024, 12, 5);
      final day = date.day.toString().padLeft(2, '0');
      expect('$day.md', '05.md');
    });

    test('should generate correct weekly summary file name', () {
      final year = 2024;
      final week = 50;
      expect('$year-W$week.md', '2024-W50.md');
    });

    test('should generate correct monthly summary file name', () {
      final year = 2024;
      final month = '12';
      expect('$year-$month.md', '2024-12.md');
    });
  });

  group('Plugin Entry Formatting', () {
    test('should format todo entry with checkbox', () {
      final done = true;
      final text = 'Complete task';
      final formatted = '- [${done ? 'x' : ' '}] $text';
      
      expect(formatted, '- [x] Complete task');
    });

    test('should format incomplete todo', () {
      final done = false;
      final text = 'Pending task';
      final formatted = '- [${done ? 'x' : ' '}] $text';
      
      expect(formatted, '- [ ] Pending task');
    });

    test('should format mood entry with emoji', () {
      final emojis = ['😢', '😕', '😐', '🙂', '😊'];
      final score = 4;
      final time = '15:30';
      final formatted = '- ${emojis[score]} ($time)';
      
      expect(formatted, '- 😊 (15:30)');
    });

    test('should format water entry with amount', () {
      final amount = 250;
      final formatted = '- ${amount}ml';
      
      expect(formatted, '- 250ml');
    });

    test('should format pomodoro entry', () {
      final duration = 25;
      final task = 'Deep work';
      final formatted = '- ${duration}min: $task';
      
      expect(formatted, '- 25min: Deep work');
    });
  });
}
