#include "gframe/card_motion.h"
#include <cmath>
#include <cstdlib>
#include <iostream>
using namespace ygo::card_motion;
static void check(bool c,const char* msg) {
	if(!c){std::cerr<<"FAILED: "<<msg<<'\n';std::exit(1);}
}
int main(){
	check(Clamp01(-2)==0.f&&Clamp01(3)==1.f,"clamping");
	check(SmoothStep(0)==0.f&&SmoothStep(1)==1.f,"fixed endpoints");
	check(MotionProgress(0,100)==0&&MotionProgress(100,100)==1,"motion endpoints");
	check(std::fabs(MotionProgress(50,100)-.5f)<.0001,"center");
	check(MotionProgress(500,100)==1.f,"slow frame cannot overshoot");
	check(MotionProgress(10,0)==1.f,"zero duration");
	check(MotionProgress(5,100)<.05f,"ease in");
	check(MotionProgress(95,100)>.95f,"ease out");
	float prev=0;
	for(int i=1;i<=100;i++){
		const float now=MotionProgress(i,100);
		check(now>=prev&&now<=1,"monotonic");
		prev=now;
	}
	for(const auto total:{12.f,22.f,30.f}){
		check(OverlayOpacity(0,total)==0.f,"preview starts invisible");
		check(OverlayOpacity(total,total)==0.f,"preview fades out");
		check(OverlayOpacity(total/2,total)>.99f,"preview visible at midpoint");
	}
	std::cout<<"Smooth card transitions: PASS\n";
}
