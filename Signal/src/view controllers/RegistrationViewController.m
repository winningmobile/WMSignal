//
//  RegistrationViewController.m
//  Signal
//
//  Created by Dylan Bourgeois on 13/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "RegistrationViewController.h"


#import "Environment.h"
#import "LocalizableText.h"
#import "PhoneNumber.h"
#import "CodeVerificationViewController.h"
#import "PhoneNumberUtil.h"
#import "RPServerRequestsManager.h"
#import "SignalKeyingStorage.h"
#import "Util.h"

static NSString *const kCodeSentSegue = @"codeSent";

@interface RegistrationViewController ()

@property CGFloat sendCodeButtonOriginalY;

@end

@implementation RegistrationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    _phoneNumberTextField.delegate = self;
    [self populateDefaultCountryNameAndCode];
    [[Environment getCurrent] setSignUpFlowNavigationController:self.navigationController];
    
    _titleLabel.text                   = NSLocalizedString(@"REGISTRATION_TITLE_LABEL", @"");
    [_countryNameButton setTitle:NSLocalizedString(@"REGISTRATION_DEFAULT_COUNTRY_NAME", @"") forState:UIControlStateNormal];
    _phoneNumberTextField.placeholder  = NSLocalizedString(@"REGISTRATION_ENTERNUMBER_DEFAULT_TEXT", @"");
    [_phoneNumberButton setTitle:NSLocalizedString(@"REGISTRATION_PHONENUMBER_BUTTON",@"") forState:UIControlStateNormal];
    [_phoneNumberButton.titleLabel setAdjustsFontSizeToFitWidth:YES];
    [_sendCodeButton setTitle:NSLocalizedString(@"REGISTRATION_VERIFY_DEVICE", @"") forState:UIControlStateNormal];
}

-(void)viewWillAppear:(BOOL)animated{
    [self adjustScreenSizes];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [_sendCodeButton setEnabled:YES];
    [_spinnerView stopAnimating];
    [_phoneNumberTextField becomeFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Locale

- (void)populateDefaultCountryNameAndCode {
    NSLocale *locale = NSLocale.currentLocale;
    NSString *countryCode = [locale objectForKey:NSLocaleCountryCode];
    NSNumber *cc = [[PhoneNumberUtil sharedInstance].nbPhoneNumberUtil getCountryCodeForRegion:countryCode];
    
    [_countryCodeButton setTitle:[NSString stringWithFormat:@"%@%@",COUNTRY_CODE_PREFIX, cc] forState:UIControlStateNormal];
    [_countryNameButton setTitle:[PhoneNumberUtil countryNameFromCountryCode:countryCode] forState:UIControlStateNormal];
}


#pragma mark - Actions

- (IBAction)sendCodeAction:(id)sender {
    NSString *phoneNumber = [NSString stringWithFormat:@"%@%@", _countryCodeButton.titleLabel.text, _phoneNumberTextField.text];
    PhoneNumber* localNumber = [PhoneNumber tryParsePhoneNumberFromUserSpecifiedText:phoneNumber];
    if(localNumber==nil){ return; }
    
    [_sendCodeButton setEnabled:NO];
    [_spinnerView startAnimating];
    [_phoneNumberTextField resignFirstResponder];
    [SignalKeyingStorage setLocalNumberTo:localNumber];
    
    [[RPServerRequestsManager sharedInstance]performRequest:[RPAPICall requestVerificationCode] success:^(NSURLSessionDataTask *task, id responseObject) {
        [self performSegueWithIdentifier:@"codeSent" sender:self];
        [_spinnerView stopAnimating];
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        
        DDLogError(@"Registration failed with information %@", error.description);
        
        UIAlertView *registrationErrorAV = [[UIAlertView alloc]initWithTitle:REGISTER_ERROR_ALERT_VIEW_TITLE
                                                                     message:REGISTER_ERROR_ALERT_VIEW_BODY
                                                                    delegate:nil
                                                           cancelButtonTitle:REGISTER_ERROR_ALERT_VIEW_DISMISS
                                                           otherButtonTitles:nil, nil];
        
        [registrationErrorAV show];
        
        [_sendCodeButton setEnabled:YES];
        [_spinnerView stopAnimating];
    }];
    
}

- (IBAction)changeCountryCodeTapped {
    CountryCodeViewController *countryCodeController = [CountryCodeViewController new];
    [self presentViewController:countryCodeController animated:YES completion:[UIUtil modalCompletionBlock]];
}

- (void)presentInvalidCountryCodeError {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:REGISTER_CC_ERR_ALERT_VIEW_TITLE
                                                        message:REGISTER_CC_ERR_ALERT_VIEW_MESSAGE
                                                       delegate:nil
                                              cancelButtonTitle:REGISTER_CC_ERR_ALERT_VIEW_DISMISS
                                              otherButtonTitles:nil];
    [alertView show];
}

#pragma mark - Keyboard notifications

- (void)initializeKeyboardHandlers{
    UITapGestureRecognizer *outsideTabRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboardFromAppropriateSubView)];
    [self.view addGestureRecognizer:outsideTabRecognizer];
}

-(void) dismissKeyboardFromAppropriateSubView {
    [self.view endEditing:NO];
}

#pragma mark - UITextFieldDelegate

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString* textBeforeChange = textField.text;
    
    // backspacing should skip over formatting characters
    UITextPosition *posIfBackspace = [textField positionFromPosition:textField.beginningOfDocument
                                                              offset:(NSInteger)(range.location + range.length)];
    UITextRange *rangeIfBackspace = [textField textRangeFromPosition:posIfBackspace toPosition:posIfBackspace];
    bool isBackspace = string.length == 0 && range.length == 1 && [rangeIfBackspace isEqual:textField.selectedTextRange];
    if (isBackspace) {
        NSString* digits = textBeforeChange.digitsOnly;
        NSUInteger correspondingDeletePosition = [PhoneNumberUtil translateCursorPosition:range.location + range.length
                                                                                     from:textBeforeChange
                                                                                       to:digits
                                                                        stickingRightward:true];
        if (correspondingDeletePosition > 0) {
            textBeforeChange = digits;
            range = NSMakeRange(correspondingDeletePosition - 1, 1);
        }
    }
    
    // make the proposed change
    NSString* textAfterChange = [textBeforeChange withCharactersInRange:range replacedBy:string];
    NSUInteger cursorPositionAfterChange = range.location + string.length;
    
    // reformat the phone number, trying to keep the cursor beside the inserted or deleted digit
    bool isJustDeletion = string.length == 0;
    NSString* textAfterReformat = [PhoneNumber bestEffortFormatPartialUserSpecifiedTextToLookLikeAPhoneNumber:textAfterChange.digitsOnly
                                                                               withSpecifiedCountryCodeString:_countryCodeButton.titleLabel.text];
    NSUInteger cursorPositionAfterReformat = [PhoneNumberUtil translateCursorPosition:cursorPositionAfterChange
                                                                                 from:textAfterChange
                                                                                   to:textAfterReformat
                                                                    stickingRightward:isJustDeletion];
    textField.text = textAfterReformat;
    UITextPosition *pos = [textField positionFromPosition:textField.beginningOfDocument
                                                   offset:(NSInteger)cursorPositionAfterReformat];
    [textField setSelectedTextRange:[textField textRangeFromPosition:pos toPosition:pos]];
    
    return NO; // inform our caller that we took care of performing the change
}

#pragma mark - Unwind segue

- (IBAction)unwindToChangeNumber:(UIStoryboardSegue*)sender {
    
}

- (IBAction)unwindToCountryCodeSelectionCancelled:(UIStoryboardSegue *)segue {
    
}

- (IBAction)unwindToCountryCodeWasSelected:(UIStoryboardSegue *)segue {
    CountryCodeViewController *vc = [segue sourceViewController];
    [_countryCodeButton setTitle:vc.callingCodeSelected forState:UIControlStateNormal];
    [_countryNameButton setTitle:vc.countryNameSelected forState:UIControlStateNormal];
    
    // Reformat phone number
    NSString* digits = _phoneNumberTextField.text.digitsOnly;
    NSString* reformattedNumber = [PhoneNumber bestEffortFormatPartialUserSpecifiedTextToLookLikeAPhoneNumber:digits
                                                                               withSpecifiedCountryCodeString:_countryCodeButton.titleLabel.text];
    _phoneNumberTextField.text = reformattedNumber;
    UITextPosition *pos = _phoneNumberTextField.endOfDocument;
    [_phoneNumberTextField setSelectedTextRange:[_phoneNumberTextField textRangeFromPosition:pos toPosition:pos]];
    
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([[segue identifier] isEqualToString:kCodeSentSegue]) {
        CodeVerificationViewController* vc =  [segue destinationViewController];
        vc.formattedPhoneNumber = [PhoneNumber bestEffortFormatPartialUserSpecifiedTextToLookLikeAPhoneNumber:_phoneNumberTextField.text withSpecifiedCountryCodeString:_countryCodeButton.titleLabel.text];
    }
}

#pragma mark iPhone 4S - Specific Code

- (void)adjustScreenSizes {
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat blueHeaderHeight;
    
    if (screenHeight < 667) {
        self.signalLogo.hidden = YES;
        blueHeaderHeight = screenHeight - 408;
    } else {
        blueHeaderHeight = screenHeight - 420;
    }
    
    _headerHeightConstraint.constant = blueHeaderHeight;
}

@end
