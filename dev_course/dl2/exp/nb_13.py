
#################################################
### THIS FILE WAS AUTOGENERATED! DO NOT EDIT! ###
#################################################
# file to edit: dev_nb/13_train_imagenette.ipynb

from exp.nb_12 import *

def noop(x): return x

class Flatten(nn.Module):
    def forward(self, x): return x.view(x.size(0), -1)

def conv(ni, nf, ks=3, stride=1, bias=False):
    return nn.Conv2d(ni, nf, kernel_size=ks, stride=stride, padding=ks//2, bias=bias)

act_fn = nn.ReLU(inplace=True)

def init_cnn(m, a=0):
    if getattr(m, 'bias', None) is not None: nn.init.constant_(m.bias, 0)
    if isinstance(m, (nn.Conv2d,nn.Linear)): nn.init.kaiming_normal_(m.weight, a=a)
    for l in m.children(): init_cnn(l, a)

def conv_layer(ni, nf, ks=3, stride=1, zero_bn=False, act=True):
    bn = nn.BatchNorm2d(nf)
    nn.init.constant_(bn.weight, 0. if zero_bn else 1.)
    layers = [conv(ni, nf, ks, stride=stride), bn]
    if act: layers.append(act_fn)
    return nn.Sequential(*layers)

class ResBlock(nn.Module):
    def __init__(self, expansion, ni, nh, stride=1):
        super().__init__()
        nf,ni = nh*expansion,ni*expansion
        layers  = [conv_layer(ni, nh, 1)]
        layers += [
            conv_layer(nh, nf, 3, stride=stride, zero_bn=True, act=False)
        ] if expansion==1 else [
            conv_layer(nh, nh, 3, stride=stride),
            conv_layer(nh, nf, 1, zero_bn=True, act=False)
        ]
        self.convs = nn.Sequential(*layers)
        self.idconv = noop if ni==nf else conv_layer(ni, nf, 1)
        self.pool = noop if stride==1 else nn.AvgPool2d(2)

    def forward(self, x): return act_fn(self.convs(x) + self.pool(self.idconv(x)))

class XResNet(nn.Sequential):
    def __init__(self, expansion, layers, num_classes=1000):
        block_szs = [64//expansion,64,128,256,512]
        blocks = [self._make_layer(expansion, block_szs[i], block_szs[i+1], l, 1 if i==0 else 2)
                  for i,l in enumerate(layers)]
        super().__init__(
            conv_layer(3, 16, stride=2), conv_layer(16, 32), conv_layer(32, 64),
            nn.MaxPool2d(kernel_size=3, stride=2, padding=1),
            *blocks,
            nn.AdaptiveAvgPool2d(1), Flatten(),
            nn.Linear(block_szs[-1]*expansion, num_classes))
        init_cnn(self)

    def _make_layer(self, expansion, ni, nf, blocks, stride):
        return nn.Sequential(*[
            ResBlock(expansion, ni if i==0 else nf, nf, stride if i==0 else 1)
            for i in range(blocks)])

def xresnet18 (**kwargs): return XResNet(1, [2, 2, 2, 2], **kwargs)
def xresnet34 (**kwargs): return XResNet(1, [3, 4, 6, 3], **kwargs)
def xresnet50 (**kwargs): return XResNet(4, [3, 4, 6, 3], **kwargs)
def xresnet101(**kwargs): return XResNet(4, [3, 4, 23, 3], **kwargs)
def xresnet152(**kwargs): return XResNet(4, [3, 8, 36, 3], **kwargs)

def get_batch(dl, learn):
    learn.xb,learn.yb = next(iter(dl))
    learn.do_begin_fit(0)
    learn('begin_batch')
    learn('after_fit')
    return learn.xb,learn.yb

def model_summary(model, find_all=False):
    xb,yb = get_batch(data.valid_dl, learn)
    mods = find_modules(model, is_lin_layer) if find_all else model.children()
    f = lambda hook,mod,inp,out: print(out.shape)
    with Hooks(mods, f) as hooks: learn.model(xb)