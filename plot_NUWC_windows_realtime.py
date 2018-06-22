#!/usr/bin/env python
import sys
sys.path.insert(0,'lib')


##  only look at shear and temp from madre
from IOlib import open_datafile 
from IOlib import seekend_datafile
from EPSIlib import Count2Volt_unipol

from EPSIlib import EPSI_channel_count

from SBElib import SBE_temp
from SBElib import SBE_cond
from SBElib import SBE_Pres
from SBElib import get_CalSBE

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.widgets import RadioButtons,Slider
from matplotlib import style

import sys


# style of graphes
style.use('fivethirtyeight')

## local library for plotting

def init_figure(numfig):
    if numfig==1:
        fig0 = plt.figure(0)
        fig1 = []
    if numfig==2:
        fig0 = plt.figure(0)
        fig1 = plt.figure(1)
    return fig0,fig1

def init_axes_fig0(fig):
    ax0=plt.axes([.3,.4,.5,.5])
    ax1=plt.axes([.1,.1,.15,.2])
    ax2=plt.axes([.3,.01,.5,.05])
    ax3=plt.axes([.3,.1,.5,.05])
    ax4=plt.axes([.1,.4,.15,.5])
    # set up subplot 
    ax0.cla()
    lineF0, = ax0.plot([],[], '.-', alpha=0.8, color="gray", markerfacecolor="red")
    lineV1, = ax0.plot([],[], '.-', alpha=0.8, color="gray", markerfacecolor="green")
    lineV2, = ax0.plot([],[], '.-', alpha=0.8, color="gray", markerfacecolor="cyan")
    radio = RadioButtons(ax1, ('Counts', 'Volts')) 
    radio1 = RadioButtons(ax4, ('t1', 't2','s1','s2','c','a1','a2','a3'))
    Sl_ymin = Slider(ax2, 'Ymin', 0, 1, valinit=.5)
    Sl_ymax = Slider(ax3, 'Ymax', 0, 1, valinit=.5)
    ax0.set_xlabel('Second')
    ax0.set_ylabel('Counts')
    return lineF0,lineV1,lineV2,radio,radio1,Sl_ymin,Sl_ymax,ax0


def init_axes_fig1(fig):
    ax0=plt.axes([.3,.4,.5,.5])
    ax1=plt.axes([.1,.1,.15,.2])
    ax2=plt.axes([.3,.01,.5,.05])
    ax3=plt.axes([.3,.1,.5,.05])
    ax4=plt.axes([.1,.4,.15,.5])
    # set up subplot 
    ax0.cla()
    lineF0, = ax0.plot([],[], '.-', alpha=0.8, color="gray", markerfacecolor="red")
    lineV1, = ax0.plot([],[], '.-', alpha=0.8, color="gray", markerfacecolor="green")
    lineV2, = ax0.plot([],[], '.-', alpha=0.8, color="gray", markerfacecolor="cyan")
    radio = RadioButtons(ax1, ('Counts', 'Volts')) 
    radio1 = RadioButtons(ax4, ('t1', 't2','s1','s2','c','a1','a2','a3'))
    Sl_ymin = Slider(ax2, 'Ymin', 0, 1, valinit=.5)
    Sl_ymax = Slider(ax3, 'Ymax', 0, 1, valinit=.5)
    ax0.set_xlabel('Second')
    ax0.set_ylabel('Counts')
    return lineF0,lineV1,lineV2,radio,radio1,Sl_ymin,Sl_ymax,ax0

def define_block(fid,eof):
    allblocks = fid.read(eof-fid.tell()) # all block should around the size of 3 MADRE block
    blocks    = allblocks.split(b'$MADRE')
    block     = blocks[1]
    block1     = blocks[2]
    blocklen  = len(block)+6
    
    aux1len=0
    aux2len=0
    epsilen=0
    
    Splitblock = block.split(b'$')
    Splitblock1 = block1.split(b'$')
    headerlen  = len(Splitblock[0])
    RTC1=int(Splitblock[0].split(b',')[0],16)
    RTC2=int(Splitblock1[0].split(b',')[0],16)    
    #freq=epsisample_per_block*32768/(RTC2-RTC1)
    freq=(RTC2-RTC1)/0.5;
    print(RTC2-RTC1)
    if Splitblock[1][:4]==b'AUX1':
        aux1len = len(Splitblock[1])
    else:
        epsilen = len(Splitblock[1])
    print(len(Splitblock))
    if len(Splitblock)>2:
        if Splitblock[2][:4]==b'AUX2':
            aux2len = len(Splitblock[2])
        else:
            epsilen = len(Splitblock[2])
    
    fid.seek(fid.tell()-len(allblocks.split(b'$MADRE')[-1])-6)    
    return blocklen,headerlen,aux1len,aux2len,epsilen,freq
    


  
def update_sample(fid,ii):
    SBEsample   = SBEsample_class
    block=fid.read(blocklen)   
    Splitblock=block.split(b'$MADRE')
    print("posi in plot buffer")
    print(ii)
    for j,dev_block in enumerate(Splitblock[1:]):
        EpsiStamp[ii]     = int(dev_block[:55].split(b',')[0],16)
        TimeStamp[ii]     = int(dev_block[:55].split(b',')[1],16)
        Voltage[ii]       = int(dev_block[:55].split(b',')[2],16)
        Checksum_aux1[ii] = int(dev_block[:55].split(b',')[3],16)
        Checksum_aux2[ii] = int(dev_block[:55].split(b',')[4],16)
        Checksum_map[ii]  = int(dev_block[:55].split(b',')[5],16)
        if (len(dev_block.split(b'AUX1'))>1):
            aux1block=dev_block[60:60+9*33].split(b'\r\n')[:-1]
            ind_epsiblock=60+9*33+5
            for k,sample in enumerate(aux1block):
                indextime=int(sample.split(b',')[0],16)
                if indextime>0:
                    Aux1Stamp[ii*(len(aux1block))+k]=int(sample.split(b',')[0],16)*freq
                    SBEsample.raw=sample.split(b',')[1]
                    SBEsample =  SBE_temp(SBEcal,SBEsample)
                    SBEsample =  SBE_Pres(SBEcal,SBEsample)
                    SBEsample =  SBE_cond(SBEcal,SBEsample)
                    T[(ii*(len(aux1block))+k)]= SBEsample.temperature
                    P[(ii*(len(aux1block))+k)]= SBEsample.pressure
                    C[(ii*(len(aux1block))+k)]= SBEsample.conductivity
                else:
                    T[(ii*(len(aux1block))+k)]= np.nan
                    P[(ii*(len(aux1block))+k)]= np.nan
                    C[(ii*(len(aux1block))+k)]= np.nan
                    Aux1Stamp[(ii*(len(aux1block))+k)]=np.nan
            else:
                ind_epsiblock=60


        epsiblock=dev_block[ind_epsiblock:]
        for k in range(epsisample_per_block):
            if (k==0):
                EPSI_time[(ii*len(epsiblock))%LepsiBuffer]= \
                                EPSI_time[(ii*len(epsiblock)-1)%LepsiBuffer]
                                
            if (np.isnan(EPSI_time[(ii*len(epsiblock))%LepsiBuffer])):
                    EPSI_time[(ii*len(epsiblock))%LepsiBuffer]=0
            EPSI_time[(ii*len(epsiblock)+k)%LepsiBuffer]=EPSI_time[(ii*len(epsiblock))%LepsiBuffer]+(k+1)/freq

            sample=epsiblock[k*EpsisampleWordLength:(k+1)*EpsisampleWordLength]
            t1[(ii*len(epsiblock)+k)%LepsiBuffer]=EPSI_channel_count(sample.hex(),0);
            t2[(ii*len(epsiblock)+k)%LepsiBuffer]=EPSI_channel_count(sample.hex(),6);
            s1[(ii*len(epsiblock)+k)%LepsiBuffer]=EPSI_channel_count(sample.hex(),12);
            s2[(ii*len(epsiblock)+k)%LepsiBuffer]=EPSI_channel_count(sample.hex(),18);
            c[(ii*len(epsiblock)+k)%LepsiBuffer]=EPSI_channel_count(sample.hex(),24);
            a1[(ii*len(epsiblock)+k)%LepsiBuffer]=EPSI_channel_count(sample.hex(),30);
            a2[(ii*len(epsiblock)+k)%LepsiBuffer]=EPSI_channel_count(sample.hex(),36);
            a3[(ii*len(epsiblock)+k)%LepsiBuffer]=EPSI_channel_count(sample.hex(),42);
            print(a1)


def animate(i,radio,radio1,Sl_ymin,Sl_ymax):
    global index_store
    global index_plot
    global EPSI_time
    global eof_old
    global time_tempo
    global data_tempo
    global index_plotmax
    
    if(radio1.value_selected=='t1'):
       data=t1
    if(radio1.value_selected=='t2'):
       data=t2
    if(radio1.value_selected=='s1'):
       data=s1
    if(radio1.value_selected=='s2'):
       data=s2
    if(radio1.value_selected=='c'):
       data=c
    if(radio1.value_selected=='a1'):
       data=a1
    if(radio1.value_selected=='a2'):
       data=a2
    if(radio1.value_selected=='a3'):
       data=a3

    if(radio1.value_selected=='c'):
        ax0xmax=500
    else:
        ax0xmax=0xffffff
        
    ax0xmin=0
    if(radio.value_selected=='Volts'):
       data=Count2Volt_unipol(data)
       ax0xmax=3.3
       ax0xmin=0
    
    if(radio1.value_selected=='c'):
       ax0xmin=Sl_ymin.val*500 
       ax0xmax=Sl_ymax.val*500
    else:
       ax0xmin=Sl_ymin.val*0xffffff 
       ax0xmax=Sl_ymax.val*0xffffff 
                
    if(radio.value_selected=='Volts'):
    	ax0xmin=Count2Volt_unipol(Sl_ymin.val*0xffffff) 
    	ax0xmax=Count2Volt_unipol(Sl_ymax.val*0xffffff) 
    	ax0.set_ylabel('Volts')
    else: 
        ax0.set_ylabel('Counts')
    
    posi=fid.tell()
    eof=fid.seek(0,2)
    fid.seek(posi)
    if (eof-eof_old)>0:
        if((eof-posi)>=blocklen):
            print(['update: %i' % index_store])

            update_sample(fid,index_store)
            index_store=(index_store+1)%LBuffer
            index_plot=np.arange(0,index_store*epsisample_per_block)
            lineF0.set_data(EPSI_time,data)

            fig0.axes[0].set_xlim([EPSI_time[0],EPSI_time[0]+.5*LBuffer])   
            fig0.axes[0].set_ylim([ax0xmin,ax0xmax]) 
            fig0.axes[0].legend(['rms=%3.3f' % np.sqrt(np.mean(data**2))],loc=2)  
    return lineF0,lineV1,lineV2,



#####################################################################

#eof=fid.seek(0,2)
#fid.seek(0)


# define classe SBE sample and epsi sample
# define classe SBE sample and epsi sample
class SBEsample_class:
    pass
class EPSIsample_class:
    pass


Aux1WordLength       = 0
ADCWordlength        = 3
number_of_sensor     = 8
epsisample_per_block = 160 # ???? 
aux1sample_per_block = 9

EpsisampleWordLength= ADCWordlength*number_of_sensor
EPSIWordlength = ADCWordlength *  number_of_sensor * epsisample_per_block

SBEcal      = get_CalSBE('0133.cal')


if len(sys.argv)>=2:
   filename=sys.argv[1]
   fid,eof=open_datafile(filename)
else:
   filename='epsi_raw.dat' 
   fid,eof=open_datafile(filename)
   
fid,eof=seekend_datafile(fid,eof)
blocklen,headerlen,aux1len,aux2len,epsilen,freq= \
                                define_block(fid,eof)


LBuffer= 5 # number of blocks stored
Lplot  = 1 # number of blocks plotted

index_plot  = 0
index_store = 0
update=True


LepsiBuffer= LBuffer*epsisample_per_block
Lepsiplot  = Lplot*epsisample_per_block

Laux1Buffer=LBuffer*aux1sample_per_block

#initialze the buffers
EpsiStamp     = np.zeros(LBuffer)*np.nan
TimeStamp     = np.zeros(LBuffer)*np.nan
Voltage       = np.zeros(LBuffer)*np.nan
Checksum_aux1 = np.zeros(LBuffer)*np.nan
Checksum_aux2 = np.zeros(LBuffer)*np.nan
Checksum_map  = np.zeros(LBuffer)*np.nan

EPSI_time=np.zeros(LepsiBuffer)*np.nan

# for circular buffer edges issues while plotting
data_tempo=np.zeros(Lepsiplot)*np.nan
time_tempo=np.zeros(Lepsiplot)*np.nan
eof_old = 0

t1=np.zeros(LepsiBuffer)*np.nan
t2=np.zeros(LepsiBuffer)*np.nan
s1=np.zeros(LepsiBuffer)*np.nan
s2=np.zeros(LepsiBuffer)*np.nan
c =np.zeros(LepsiBuffer)*np.nan
a1=np.zeros(LepsiBuffer)*np.nan
a2=np.zeros(LepsiBuffer)*np.nan
a3=np.zeros(LepsiBuffer)*np.nan

if aux1len>0:
   Aux1Stamp=np.zeros(Laux1Buffer)
   T=np.zeros(Laux1Buffer)*np.nan
   C=np.zeros(Laux1Buffer)*np.nan
   P=np.zeros(Laux1Buffer)*np.nan






if aux1len>0:
#    fig0,fig1=init_figure(2)    
    fig0,fig1=init_figure(1) # just the for dev    
    lineF0,lineV1,lineV2,radio,radio1,Sl_ymin,Sl_ymax,ax0= \
                                            init_axes_fig0(fig0)
else:
    fig0,fig1=init_figure(1)    
    lineF0,lineV1,lineV2,radio,radio1,Sl_ymin,Sl_ymax,ax0= \
                                            init_axes_fig0(fig0)
    
    
ani = animation.FuncAnimation(fig0, animate,fargs=(radio,radio1,Sl_ymin,Sl_ymax),interval=10)
plt.show()
   


