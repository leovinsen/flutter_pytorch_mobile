#import "PyTorchMobilePlugin.h"
#import "TorchModule.h"
#import "UIImageExtension.h"
#import <LibTorch/LibTorch.h>

@implementation PytorchMobilePlugin

NSMutableArray *modules = [[NSMutableArray alloc] init];

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"pytorch_mobile"
                                     binaryMessenger:[registrar messenger]];
    PytorchMobilePlugin* instance = [[PytorchMobilePlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSArray *methods = @[@"loadModel", @"predict", @"predictImage"];
    int method = (int)[methods indexOfObject:call.method];
    switch(method) {
        case 0:
        {
            try {
                NSString *absPath = call.arguments[@"absPath"];
                TorchModule *module = [[TorchModule alloc]initWithFileAtPath: absPath];
                [modules addObject: module];
                result(@([modules count] - 1));
            } catch (const std::exception& e){
                NSString *assetPath = call.arguments[@"assetPath"];
                NSLog(@"PyTorchMobile: %@ is not a proper model %s", assetPath, e.what());
                break;
            }
            break;
        }
        case 1:
        {
            TorchModule *module;
            NSString *dtype;
            NSArray<NSNumber*>* shape;
            NSArray<NSNumber*>* data;
            
            try {
                int index = [call.arguments[@"index"] intValue];
                module = modules[index];
                dtype = call.arguments[@"dtype"];
                shape = call.arguments[@"shape"];
                data = call.arguments[@"data"];
            } catch (const std::exception& e) {
                NSLog(@"PyTorchMobile: error parsing arguments!\n%s", e.what());
            }
            
            try {

                // Force input into Long; original version uses Float
                int len = (int) [data count];
                long input[len];
                for(int i = 0; i < len; i++) {
                    input[i] = [ data[i] longValue];
                }
                NSArray<NSNumber*>* output = [module predict:&input withShape:shape andDtype:dtype];
                result(output);
            } catch (const std::exception& e) {
                NSLog(@"PyTorchMobile: %s", e.what());
                result(nil);
            }

            break;
        }
        case 2:
        {
            TorchModule *imageModule;
            float* input;
            int width;
            int height;
            try {
                int index = [call.arguments[@"index"] intValue];
                imageModule = modules[index];
                
                FlutterStandardTypedData *imageData = call.arguments[@"image"];
                width = [call.arguments[@"width"] intValue];
                height = [call.arguments[@"height"] intValue];
                
                UIImage *image = [UIImage imageWithData: imageData.data];
                image = [UIImageExtension resize:image toWidth:width toHeight:height];
                
                input = [UIImageExtension normalize:image];
            } catch (const std::exception& e) {
                NSLog(@"PyTorchMobile: error reading image!\n%s", e.what());
            }
            try {
                NSArray<NSNumber*>* output  = [imageModule predictImage:input withWidth:width andHeight: height];
                
                result(output);
            } catch (const std::exception& e) {
                NSLog(@"PyTorchMobile: %s", e.what());
            }
          
            break;
        }
        default:
        {
            result(FlutterMethodNotImplemented);
            break;
        }
    }
}

@end
