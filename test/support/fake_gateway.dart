import 'package:bojian_mobile/guidance_help.dart';
import 'package:fixnum/fixnum.dart';
import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/api/generated/auth.pb.dart' as auth;
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/wechat_login.dart';
import 'package:bojian_mobile/douyin_login.dart';

class MemoryStorage implements SessionStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class FakeWeChatAuthorizer implements WeChatAuthorizer {
  FakeWeChatAuthorizer({this.code = 'wx-test-code'});
  String? code;
  int calls = 0;

  @override
  Future<String?> authorize() async {
    calls++;
    return code;
  }
}

class FakeDouyinAuthorizer implements DouyinAuthorizer {
  FakeDouyinAuthorizer({this.code = 'dy-test-code'});
  String? code;
  int calls = 0;

  @override
  Future<String?> authorize() async {
    calls++;
    return code;
  }
}

class FakeGateway implements ApiGateway {
  String? failing;
  bool rejectLogin = false;
  final calls = <String>[];
  final documents = <String, Map<String, dynamic>>{};
  Map<String, dynamic>? lastBody;
  Map<String, dynamic>? lastMutationBody;
  Map<String, String>? lastHeaders;
  FakeGateway({bool seeded = false}) {
    documents['GetMeIdentityVerification'] = {'status': 'NOT_VERIFIED'};
    documents['GetMe'] = {
      'nickname': '测试账号',
      'bio': '',
      'public_id': 'test-id',
      'profile_visibility': 'PUBLIC',
      'phone_masked': '138****5678',
    };
    documents['GetWallet'] = {'available_points': 0};
    documents['GetWalletDailyReward'] = {'points': 10, 'claimable': true};
    if (seeded) {
      documents['GetFeed'] = {
        'items': [
          {
            'id': 1,
            'title': '一页简历拿到 5 个面试，\n我删掉了这些内容',
            'author': {'id': 2, 'display_name': '测试作者', 'city': ''},
            'content': richContent('测试文章正文'),
            'published_at': '2026-10-07T00:00:00Z',
            'is_liked': false,
            'is_favorited': false,
            'like_count': 0,
          },
        ],
      };
      documents['GetResumes'] = {
        'items': [
          {
            'id': 1,
            'revision': 3,
            'title': '产品经理 · 社招简历',
            'content': {
              'personal_info': {
                'full_name': '测试用户',
                'phone': '13812345678',
                'email': '',
              },
              'job_expectation': {
                'position': '产品经理',
                'city': '',
                'preference': '',
              },
              'work_experiences': [],
              'educations': [],
              'skills': [],
            },
          },
        ],
      };
      documents['GetUsersSearch'] = {
        'items': [
          {
            'id': 2,
            'display_name': '周予安',
            'public_id': 'test-friend',
            'relationship': 'NONE',
          },
        ],
      };
    }
  }
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    calls.add(method);
    lastBody = body;
    if (body != null) lastMutationBody = body;
    lastHeaders = headers;
    if (failing == method) throw const ApiFailure('服务器暂不可用');
    if (method == 'PatchMe') {
      documents['GetMe'] = {...documents['GetMe']!, ...body!};
    }
    if (method == 'PostMePhone') {
      final phone = body!['phone'] as String;
      final masked = '${phone.substring(0, 3)}****${phone.substring(7)}';
      documents['GetMe'] = {...documents['GetMe']!, 'phone_masked': masked};
      return ApiDocument({'phone_masked': masked});
    }
    if (method == 'PostArticlesIdComments') {
      final rows =
          (documents['GetArticlesIdComments']?['items'] as List? ?? []);
      documents['GetArticlesIdComments'] = {
        'items': [
          ...rows,
          {
            'author': {'display_name': '测试账号'},
            'content': body!['content'],
          },
        ],
      };
    }
    if (method == 'PatchResumesId' || method == 'PostResumes') {
      documents['GetResumes'] = {
        'items': [
          {
            'id': integer(path['id']) == 0 ? 1 : integer(path['id']),
            'revision': 4,
            ...body!,
          },
        ],
      };
    }
    if (method == 'PostResumes' || method == 'PatchResumesId') {
      return ApiDocument(
        (documents['GetResumes']!['items'] as List).first
            as Map<String, dynamic>,
      );
    }
    return ApiDocument(documents[method] ?? {'items': []});
  }

  @override
  Future<CaptchaChallenge> createCaptcha(Map<String, String> headers) async {
    calls.add('CreateCaptcha');
    const image =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aXioAAAAASUVORK5CYII=';
    return CaptchaChallenge(
      pieceY: 0,
      maxX: 200,
      id: 'captcha-test',
      masterImageDataUrl: image,
      thumbImageDataUrl: image,
    );
  }

  @override
  Future<auth.CaptchaVerification> verifyCaptcha(
    String id,
    int angle,
    Map<String, String> headers,
  ) async {
    calls.add('VerifyCaptcha');
    return auth.CaptchaVerification(captchaToken: 'verified-test');
  }

  @override
  Future<auth.SMSResponse> sendSMS(
    String phone,
    String token,
    Map<String, String> headers,
  ) async {
    calls.add('SendSMS');
    return auth.SMSResponse(retryAfterSeconds: 30);
  }

  @override
  Future<auth.LoginResponse> login(
    String phone,
    String code,
    Map<String, String> headers,
  ) async {
    if (rejectLogin) throw const ApiFailure('验证码不正确');
    return auth.LoginResponse(
      accessToken: 'test-access',
      refreshToken: 'test-refresh',
      user: auth.UserIdentity(id: Int64(1), publicId: 'test-id'),
    );
  }

  @override
  Future<auth.LoginResponse> loginWithWeChat(
    String code,
    Map<String, String> agreementVersions,
    Map<String, String> headers,
  ) async {
    calls.add('WeChatLogin');
    if (failing == 'WeChatLogin') throw const ApiFailure('微信登录失败，请稍后重试');
    return login('', code, headers);
  }

  @override
  Future<auth.LoginResponse> loginWithDouyin(
    String code,
    Map<String, String> agreementVersions,
    Map<String, String> headers,
  ) async {
    calls.add('DouyinLogin');
    if (failing == 'DouyinLogin') throw const ApiFailure('抖音登录失败，请稍后重试');
    return login('', code, headers);
  }

  @override
  Future<auth.LoginResponse> confirmRegistration(
    String registrationToken,
    Map<String, String> agreements,
    Map<String, String> headers,
  ) async {
    calls.add('ConfirmRegistration');
    return login('', '', headers);
  }

  @override
  Future<auth.TokenResponse> refresh(
    String token,
    Map<String, String> headers,
  ) async => auth.TokenResponse(
    accessToken: 'refreshed-test',
    refreshToken: 'test-refresh',
  );
  @override
  Future<void> close() async {}
}

Future<AppStore> testStore({
  bool authenticated = false,
  bool seeded = false,
  bool guidanceHelpSeen = true,
  FakeGateway? api,
  WeChatAuthorizer? weChatAuthorizer,
  DouyinAuthorizer? douyinAuthorizer,
}) async {
  final store = AppStore(
    api: api ?? FakeGateway(seeded: seeded),
    storage: MemoryStorage(),
    weChatAuthorizer: weChatAuthorizer,
    douyinAuthorizer: douyinAuthorizer,
  );
  await store.initialize();
  if (authenticated) {
    await store.signIn('13812345678', '654321');
    await store.loadAll();
  }
  if (guidanceHelpSeen) {
    for (final tour in guidanceTourIds) {
      await store.storage.write(
        guidanceTourStorageKey(store.userID, tour),
        'seen',
      );
    }
  }
  return store;
}
