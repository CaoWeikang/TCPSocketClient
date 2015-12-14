//
//  ViewController.m
//  TCPSocketClient
//
//  Created by macairwkcao on 15/12/11.
//  Copyright © 2015年 CWK. All rights reserved.
//

#import "ViewController.h"
#import "AsyncSocket.h"
@interface ViewController ()<AsyncSocketDelegate,UITextViewDelegate>
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UITextField *textField;

@end

@implementation ViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        clientSocket = [[AsyncSocket alloc] initWithDelegate:self];
        [clientSocket setRunLoopModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
//        messages = [[NSMutableArray alloc] initWithCapacity:1];
    }
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        clientSocket = [[AsyncSocket alloc] initWithDelegate:self];
        [clientSocket setRunLoopModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
        //        messages = [[NSMutableArray alloc] initWithCapacity:1];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyBoardWasChanged:)
                                                     name:UIKeyboardWillShowNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyBoardWasChanged:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)connectToServer:(id)sender {
    [self connectHost:@"172.16.0.144" port:53450];
    NSOutputStream * readStream = (NSOutputStream *) [clientSocket getCFReadStream];
    NSInputStream * writeStream = (NSInputStream *)[clientSocket getCFWriteStream];
    if ([readStream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType]) {
        [readStream open];

    }
    if ([writeStream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType]){
        [writeStream open];
    }
}
- (IBAction)disconnectFromServer:(id)sender {
    [clientSocket disconnect];
}
- (IBAction)cleanMessage:(id)sender {
    self.textView.text = nil;
}
- (IBAction)sendMessage:(id)sender {
    NSString *msg = self.textField.text;
    if (msg.length > 0) {
        self.textView.text = [NSString stringWithFormat:@"%@\nself:%@",self.textView.text,msg];
        [self writeData:msg];
    }
    self.textField.text = nil;
    [self.textField resignFirstResponder];
    
}

- (void)connectHost:(NSString *)ip port:(NSUInteger)port
{
    self.textView.text = nil;
    if (![clientSocket isConnected])
    {
        NSError *error = nil;
        [clientSocket connectToHost:ip onPort:port withTimeout:-1 error:&error];
        if (error)
        {
            
        
            NSLog(@"connectToHost error %@",error);
            [clientSocket disconnect];
        }
    }
}


-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.textField resignFirstResponder];
}

#pragma mark - textView
-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return NO;
}
-(BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    [textView resignFirstResponder];
    
    return NO;
}

#pragma mark Delegate

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    NSLog(@"client willDisconnectWithError:%@",err);
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
//    [messages insertObject:@"服务器已断开" atIndex:0];
//    [self.chatTableView reloadData];
    NSLog(@"client onSocketDidDisconnect");
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    
    NSLog(@"client didConnectToHost");
    
//    self.resultTextview.text = host;
    
    //这是异步返回的连接成功，
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if(msg)
    {
        self.textView.text = [NSString stringWithFormat:@"%@\nServer:%@",self.textView.text,msg];
    }
    [sock readDataWithTimeout:-1 tag:0];
    
    UIApplication *application=[UIApplication sharedApplication];
    if (application.applicationState==UIApplicationStateBackground||application.applicationState==UIApplicationStateInactive )
    {
        [self scheduleNotification:msg];
    }
    

}
- (void)scheduleNotification:(NSString *)name
{
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    //设置5秒之后
    NSDate *pushDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
    if (notification != nil) {
        // 设置推送时间（5秒后）
        notification.fireDate = pushDate;
        // 设置时区（此为默认时区）
        notification.timeZone = [NSTimeZone defaultTimeZone];
        // 设置重复间隔（默认0，不重复推送）
        notification.repeatInterval = 0;
        // 推送声音（系统默认）
        notification.soundName = UILocalNotificationDefaultSoundName;
        // 推送内容
        notification.alertBody = name;
        //显示在icon上的数字
        notification.applicationIconBadgeNumber ++;
        //设置userinfo 方便在之后需要撤销的时候使用
        NSDictionary *info = [NSDictionary dictionaryWithObject:@"name"forKey:@"key"];
        notification.userInfo = info;
        //添加推送到UIApplication
        UIApplication *app = [UIApplication sharedApplication];
        [app scheduleLocalNotification:notification];
    }
}

- (void)writeData:(NSString *)string
{
    NSData *cmdData = [string dataUsingEncoding:NSUTF8StringEncoding];
    [clientSocket writeData:cmdData withTimeout:-1 tag:0];
}

-(void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    NSLog(@"client didWriteDataWithTag:%ld",tag);
    [sock readDataWithTimeout:-1 tag:0];
}

-(void)keyBoardWasChanged:(NSNotification *)info
{
    NSDictionary *dict = [info userInfo];
    CGRect beginRect = [[dict objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGRect endRect = [[dict objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    CGRect frame = self.view.frame;
    
    frame.size.width+=beginRect.origin.x-endRect.origin.x;
    frame.size.height -= beginRect.origin.y-endRect.origin.y;
    [UIView beginAnimations:@"ResizeForKeyBoard" context:nil];
    [UIView setAnimationDuration:[dict[UIKeyboardAnimationDurationUserInfoKey] floatValue]];
    [UIView setAnimationCurve:[dict [UIKeyboardAnimationCurveUserInfoKey] floatValue]];
    self.view.frame = frame;
    [UIView commitAnimations];
    
}


-(void)dealloc
{
    [clientSocket disconnect];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
