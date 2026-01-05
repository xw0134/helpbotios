#import "AppController.h"
#import "cocos2d.h"
#import "HelloWorldScene.h"

@implementation AppController

@synthesize window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 创建窗口
    CGRect bounds = [[UIScreen mainScreen] bounds];
    self.window = [[UIWindow alloc] initWithFrame:bounds];
    
    // 初始化 Cocos2d-x
    cocos2d::Application *app = cocos2d::Application::getInstance();
    
    // 创建 OpenGL 视图
    CCEAGLView *eaglView = [CCEAGLView viewWithFrame:bounds
                                         pixelFormat:kEAGLColorFormatRGBA8
                                         depthFormat:GL_DEPTH24_STENCIL8_OES
                                  preserveBackbuffer:NO
                                          sharegroup:nil
                                       multiSampling:NO
                                     numberOfSamples:0];
    
    // 设置为根视图控制器
    UIViewController *viewController = [[UIViewController alloc] init];
    viewController.view = eaglView;
    self.window.rootViewController = viewController;
    
    [self.window makeKeyAndVisible];
    
    // 运行 Cocos2d-x
    app->run();
    
    // 创建场景
    auto scene = HelloWorld::createScene();
    cocos2d::Director::getInstance()->runWithScene(scene);
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    cocos2d::Director::getInstance()->pause();
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    cocos2d::Director::getInstance()->resume();
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    cocos2d::Application::getInstance()->applicationDidEnterBackground();
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    cocos2d::Application::getInstance()->applicationWillEnterForeground();
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // 清理资源
}

@end
