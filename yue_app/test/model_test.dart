import 'package:yue_app/models/user_model.dart';
import 'package:yue_app/models/post_model.dart';
import 'package:yue_app/models/auth_model.dart';

/// Basic unit tests for model parsing.
/// Run with: flutter test test/model_test.dart
/// Or standalone: dart test/model_test.dart
void main() {
  // Test UserModel
  _testUserModel();
  // Test PostModel
  _testPostModel();
  // Test AuthResponse
  _testAuthResponse();

  print('All model tests passed!');
}

void _testUserModel() {
  final json = {
    'user_id': 'test_user',
    'nickname': 'Test User',
    'avatar': 'https://example.com/avatar.jpg',
    'bio': 'Hello world',
    'location': 'Beijing',
    'verified': 1,
    'gender': 'male',
    'background': 'https://example.com/bg.jpg',
  };

  final user = UserModel.fromJson(json);
  assert(user.userId == 'test_user');
  assert(user.nickname == 'Test User');
  assert(user.avatar == 'https://example.com/avatar.jpg');
  assert(user.bio == 'Hello world');
  assert(user.verified == 1);

  final toJson = user.toJson();
  assert(toJson['user_id'] == 'test_user');
  assert(toJson['nickname'] == 'Test User');

  // Test with null values
  final emptyUser = UserModel.fromJson({});
  assert(emptyUser.userId == null);
  assert(emptyUser.nickname == null);

  print('  ✓ UserModel tests passed');
}

void _testPostModel() {
  final json = {
    'id': 1,
    'title': 'Test Post',
    'content': 'This is a test post',
    'images': ['https://example.com/img1.jpg', 'https://example.com/img2.jpg'],
    'type': 1,
    'user_id': 'user_001',
    'likes_count': 100,
    'comments_count': 50,
    'collects_count': 30,
    'created_at': '2024-01-01T00:00:00Z',
    'user': {
      'user_id': 'user_001',
      'nickname': 'Author',
      'avatar': 'https://example.com/avatar.jpg',
    },
  };

  final post = PostModel.fromJson(json);
  assert(post.id == 1);
  assert(post.title == 'Test Post');
  assert(post.images.length == 2);
  assert(post.type == 1);
  assert(post.likesCount == 100);
  assert(post.user != null);
  assert(post.user!.nickname == 'Author');

  // Test with JSON string images
  final jsonStringImages = {
    'id': 2,
    'title': 'Post with JSON string images',
    'images': '["url1","url2"]',
  };
  final post2 = PostModel.fromJson(jsonStringImages);
  assert(post2.images.length == 2);

  // Test with empty data
  final emptyPost = PostModel.fromJson({});
  assert(emptyPost.id == null);
  assert(emptyPost.images.isEmpty);

  print('  ✓ PostModel tests passed');
}

void _testAuthResponse() {
  final json = {
    'access_token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    'refresh_token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    'expires_in': 3600,
    'user': {
      'user_id': 'user_001',
      'nickname': 'Test User',
    },
  };

  final auth = AuthResponse.fromJson(json);
  assert(auth.accessToken != null);
  assert(auth.refreshToken != null);
  assert(auth.expiresIn == 3600);
  assert(auth.user != null);
  assert(auth.user!.userId == 'user_001');

  // Test with minimal data
  final minAuth = AuthResponse.fromJson({'access_token': 'token123'});
  assert(minAuth.accessToken == 'token123');
  assert(minAuth.refreshToken == null);
  assert(minAuth.user == null);

  print('  ✓ AuthResponse tests passed');
}
