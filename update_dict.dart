import 'dart:io';
import 'dart:convert';

void main() async {
  final enAdds = {
    "no_events_found": "No events found.",
    "free": "Free",
    "most_recent": "Most Recent",
    "nearest_event": "Nearest Event",
    "farthest_event": "Farthest Event",
    "no_location": "No location provided",
    "schedules": "Schedules:",
    "no_specific_times": "No specific times.",
    "free_caps": "FREE",
    "change_avatar": "Change Avatar",
    "choose_gallery": "Choose from Gallery",
    "take_photo": "Take a Photo",
    "err_fullname_empty": "Full name cannot be empty.",
    "update_profile": "Update Profile",
    "confirm_save_changes": "Are you sure you want to save these changes?",
    "profile_updated_success": "Profile updated successfully!",
    "err_picking_image": "Error picking image",
    "err_pass_length": "New password must be at least 6 characters long.",
    "err_pass_match": "New password and confirm password do not match.",
    "err_current_pass": "Current password is required.",
    "change_password": "Change Password",
    "confirm_change_password": "Are you sure you want to securely change your password?",
    "pass_changed_success": "Password changed successfully!",
    "please_login": "Please log in to view your profile.",
    "user_profile": "User Profile",
    "student_id_prefix": "Student ID: ",
    "edit_profile": "Edit Profile",
    "saved_posts": "Saved Posts",
    "security_settings": "Security Settings",
    "current_password": "Current Password",
    "new_password": "New Password",
    "confirm_new_password": "Confirm New Password",
    "error_prefix": "Error: ",
    "incorrect_password": "Current password is incorrect."
  };

  final msAdds = {
    "no_events_found": "Tiada acara ditemui.",
    "free": "Percuma",
    "most_recent": "Paling Baru",
    "nearest_event": "Acara Terdekat",
    "farthest_event": "Acara Terjauh",
    "no_location": "Tiada lokasi disediakan",
    "schedules": "Jadual:",
    "no_specific_times": "Tiada masa khusus.",
    "free_caps": "PERCUMA",
    "change_avatar": "Tukar Avatar",
    "choose_gallery": "Pilih dari Galeri",
    "take_photo": "Ambil Gambar",
    "err_fullname_empty": "Nama penuh tidak boleh kosong.",
    "update_profile": "Kemaskini Profil",
    "confirm_save_changes": "Adakah anda pasti mahu menyimpan perubahan ini?",
    "profile_updated_success": "Profil berjaya dikemaskini!",
    "err_picking_image": "Ralat memilih gambar",
    "err_pass_length": "Kata laluan baru mestilah sekurang-kurangnya 6 aksara.",
    "err_pass_match": "Kata laluan baru dan sahkan kata laluan tidak sepadan.",
    "err_current_pass": "Kata laluan semasa diperlukan.",
    "change_password": "Tukar Kata Laluan",
    "confirm_change_password": "Adakah anda pasti mahu menukar kata laluan dengan selamat?",
    "pass_changed_success": "Kata laluan berjaya ditukar!",
    "please_login": "Sila log masuk untuk melihat profil anda.",
    "user_profile": "Profil Pengguna",
    "student_id_prefix": "ID Pelajar: ",
    "edit_profile": "Sunting Profil",
    "saved_posts": "Catatan Disimpan",
    "security_settings": "Tetapan Keselamatan",
    "current_password": "Kata Laluan Semasa",
    "new_password": "Kata Laluan Baru",
    "confirm_new_password": "Sahkan Kata Laluan Baru",
    "error_prefix": "Ralat: ",
    "incorrect_password": "Kata laluan semasa tidak betul."
  };

  final zhAdds = {
    "no_events_found": "未找到活动。",
    "free": "免费",
    "most_recent": "最新",
    "nearest_event": "最近活动",
    "farthest_event": "最远活动",
    "no_location": "未提供地点",
    "schedules": "时间表:",
    "no_specific_times": "没有具体时间。",
    "free_caps": "免费",
    "change_avatar": "更改头像",
    "choose_gallery": "从图库选择",
    "take_photo": "拍照",
    "err_fullname_empty": "全名不能为空。",
    "update_profile": "更新个人资料",
    "confirm_save_changes": "您确定要保存这些更改吗？",
    "profile_updated_success": "个人资料更新成功！",
    "err_picking_image": "选择图片时出错",
    "err_pass_length": "新密码必须至少6个字符。",
    "err_pass_match": "新密码与确认密码不一致。",
    "err_current_pass": "需要当前密码。",
    "change_password": "更改密码",
    "confirm_change_password": "您确定要安全地更改密码吗？",
    "pass_changed_success": "密码更改成功！",
    "please_login": "请登录以查看您的个人资料。",
    "user_profile": "用户个人资料",
    "student_id_prefix": "学号: ",
    "edit_profile": "编辑个人资料",
    "saved_posts": "已保存的帖子",
    "security_settings": "安全设置",
    "current_password": "当前密码",
    "new_password": "新密码",
    "confirm_new_password": "确认新密码",
    "error_prefix": "错误: ",
    "incorrect_password": "当前密码不正确。"
  };

  final jaAdds = {
    "no_events_found": "イベントが見つかりません。",
    "free": "無料",
    "most_recent": "最新",
    "nearest_event": "最も近いイベント",
    "farthest_event": "最も遠いイベント",
    "no_location": "場所が指定されていません",
    "schedules": "スケジュール:",
    "no_specific_times": "特定の時間はありません。",
    "free_caps": "無料",
    "change_avatar": "アバターを変更",
    "choose_gallery": "ギャラリーから選択",
    "take_photo": "写真を撮る",
    "err_fullname_empty": "フルネームは空にできません。",
    "update_profile": "プロフィールを更新",
    "confirm_save_changes": "これらの変更を保存してもよろしいですか？",
    "profile_updated_success": "プロフィールが正常に更新されました！",
    "err_picking_image": "画像の選択エラー",
    "err_pass_length": "新しいパスワードは6文字以上である必要があります。",
    "err_pass_match": "新しいパスワードと確認用パスワードが一致しません。",
    "err_current_pass": "現在のパスワードが必要です。",
    "change_password": "パスワードを変更",
    "confirm_change_password": "パスワードを安全に変更してもよろしいですか？",
    "pass_changed_success": "パスワードが正常に変更されました！",
    "please_login": "プロフィールを表示するにはログインしてください。",
    "user_profile": "ユーザープロフィール",
    "student_id_prefix": "学生ID: ",
    "edit_profile": "プロフィールを編集",
    "saved_posts": "保存された投稿",
    "security_settings": "セキュリティ設定",
    "current_password": "現在のパスワード",
    "new_password": "新しいパスワード",
    "confirm_new_password": "新しいパスワードを確認",
    "error_prefix": "エラー: ",
    "incorrect_password": "現在のパスワードが間違っています。"
  };

  Future<void> updateDict(String filename, Map<String, String> additions) async {
    final pathStr = 'c:/Users/ASUS/StudioProjects/uni_path/assets/translations/' + filename;
    final file = File(pathStr);
    Map<String, dynamic> data = {};
    if (await file.exists()) {
      data = jsonDecode(await file.readAsString());
    }
    data.addAll(additions);
    await file.writeAsString(jsonEncode(data));
    print('Updated ' + filename);
  }

  await updateDict('en.json', enAdds);
  await updateDict('ms.json', msAdds);
  await updateDict('zh.json', zhAdds);
  await updateDict('ja.json', jaAdds);
}
