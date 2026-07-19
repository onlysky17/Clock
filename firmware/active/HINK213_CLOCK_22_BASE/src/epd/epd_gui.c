

#include "epd.h"


/******************************************************************************/


// FBå‚æ•°
int fb_w;
int fb_h;

/* HINK-E0213A53 physical override: 122x250 controller RAM, 16*250 = 4000. */
u8 fb_bw[EPD_FRAME_BYTES];

/******************************************************************************/


void draw_pixel(int x, int y, int color)
{
	int nx, ny;
	int rmode = scr_mode&0x03;
	
	if(rmode==0){
		nx = x;
		ny = y;
	}else if(rmode==1){
		nx = scr_w-1-y;
		ny = x;
	}else if(rmode==2){
		nx = scr_w-1-x;
		ny = scr_h-1-y;
	}else if(rmode==3){
		nx = y;
		ny = scr_h-1-x;
	}
	if(scr_mode&MIRROR_H){
		nx += scr_padding;
	}

	int byte_pos = ny*line_bytes+(nx>>3);
	int bit_mask = 0x80>>(nx&7);

	if(color!=WHITE){
		fb_bw[byte_pos] &= ~bit_mask;
	}
	if(scr_mode&EPD_BWR && color==RED){
		fb_rr[byte_pos] |=  bit_mask;
	}
}


void draw_hline(int y, int x1, int x2, int color)
{
	int x;
	if(x1>x2){
		x = x1;
		x1 = x2;
		x2 = x;
	}
	
	for(x=x1; x<=x2; x+=1){
		draw_pixel(x, y, color);
	}
}


void draw_vline(int x, int y1, int y2, int color)
{
	int y;
	if(y1>y2){
		x = y1;
		y1 = y2;
		y2 = x;
	}
	
	for(y=y1; y<=y2; y+=1){
		draw_pixel(x, y, color);
	}
}


void draw_rect(int x1, int y1, int x2, int y2, int color)
{
	draw_hline(y1, x1, x2, color);
	draw_hline(y2, x1, x2, color);
	draw_vline(x1, y1, y2, color);
	draw_vline(x2, y1, y2, color);
}


void draw_box(int x1, int y1, int x2, int y2, int color)
{
	int y;
	
	for(y=y1; y<=y2; y++){
		draw_hline(y, x1, x2, color);
	}
}



/**
 * ç»˜åˆ¶äºŒç»´ç åˆ°å¢¨æ°´å±
 *
 * @param start_x   ç»˜åˆ¶èµ·å§‹Xä½ç½®
 * @param start_y   ç»˜åˆ¶èµ·å§‹Yä½ç½®
 * @param pix_size  æ¯ä¸ªäºŒç»´ç åƒç´ ç‚¹çš„å®½é«˜ï¼ˆå•ä½åƒç´ ï¼‰
 * @param img       äºŒç»´ç Cæ•°ç»„ï¼Œå°ºå¯¸31x4ï¼Œæ¯è¡Œ4å­—èŠ‚
 */
void draw_qr_code(
    int start_x,
    int start_y,
    int pix_size,
    const unsigned char img[31][4]
) {
    for (int y = 0; y < 31; y++) {
        for (int x = 0; x < 31; x++) {

            int byte_idx = x / 8;       // æ¯4å­—èŠ‚ä¸€è¡Œï¼Œ8bitä¸€ä¸ªå­—èŠ‚
            int bit_idx = 7 - (x % 8);  // å›¾åƒä»Žé«˜ä½åˆ°ä½Žä½å­˜å‚¨
            int bit = (img[y][byte_idx] >> bit_idx) & 1;
            int color = (bit == 0) ? WHITE : BLACK;

            // æ”¾å¤§ç»˜åˆ¶
            int x1 = start_x + x * pix_size;
            int y1 = start_y + y * pix_size;
            int x2 = x1 + pix_size - 1;
            int y2 = y1 + pix_size - 1;

            draw_box(x1, y1, x2, y2, color);
        }
    }
}

/******************************************************************************/


#define COMPACT_GLYPH_W 5
#define COMPACT_GLYPH_H 7
#define COMPACT_GLYPH_ADV 6

static const u8 compact_glyph_digit[10][COMPACT_GLYPH_H] = {
	{0x0e,0x11,0x13,0x15,0x19,0x11,0x0e},
	{0x04,0x0c,0x04,0x04,0x04,0x04,0x0e},
	{0x0e,0x11,0x01,0x02,0x04,0x08,0x1f},
	{0x1e,0x01,0x01,0x0e,0x01,0x01,0x1e},
	{0x02,0x06,0x0a,0x12,0x1f,0x02,0x02},
	{0x1f,0x10,0x10,0x1e,0x01,0x01,0x1e},
	{0x06,0x08,0x10,0x1e,0x11,0x11,0x0e},
	{0x1f,0x01,0x02,0x04,0x08,0x08,0x08},
	{0x0e,0x11,0x11,0x0e,0x11,0x11,0x0e},
	{0x0e,0x11,0x11,0x0f,0x01,0x02,0x0c},
};

static const u8 compact_glyph_colon[COMPACT_GLYPH_H] = {
	0x00,0x04,0x04,0x00,0x04,0x04,0x00
};

static const u8 compact_glyph_slash[COMPACT_GLYPH_H] = {
	0x01,0x02,0x02,0x04,0x08,0x08,0x10
};

static const u8 compact_glyph_dash[COMPACT_GLYPH_H] = {
	0x00,0x00,0x00,0x1f,0x00,0x00,0x00
};

static const u8 compact_glyph_question[COMPACT_GLYPH_H] = {
	0x0e,0x11,0x01,0x02,0x04,0x00,0x04
};

static const u8 compact_glyph_alpha[26][COMPACT_GLYPH_H] = {
	{0x0e,0x11,0x11,0x1f,0x11,0x11,0x11}, /* A */
	{0x1e,0x11,0x11,0x1e,0x11,0x11,0x1e},
	{0x0f,0x10,0x10,0x10,0x10,0x10,0x0f},
	{0x1e,0x11,0x11,0x11,0x11,0x11,0x1e},
	{0x1f,0x10,0x10,0x1e,0x10,0x10,0x1f},
	{0x1f,0x10,0x10,0x1e,0x10,0x10,0x10},
	{0x0f,0x10,0x10,0x13,0x11,0x11,0x0f},
	{0x11,0x11,0x11,0x1f,0x11,0x11,0x11},
	{0x0e,0x04,0x04,0x04,0x04,0x04,0x0e},
	{0x01,0x01,0x01,0x01,0x11,0x11,0x0e},
	{0x11,0x12,0x14,0x18,0x14,0x12,0x11},
	{0x10,0x10,0x10,0x10,0x10,0x10,0x1f},
	{0x11,0x1b,0x15,0x15,0x11,0x11,0x11},
	{0x11,0x19,0x15,0x13,0x11,0x11,0x11},
	{0x0e,0x11,0x11,0x11,0x11,0x11,0x0e},
	{0x1e,0x11,0x11,0x1e,0x10,0x10,0x10},
	{0x0e,0x11,0x11,0x11,0x15,0x12,0x0d},
	{0x1e,0x11,0x11,0x1e,0x14,0x12,0x11},
	{0x0f,0x10,0x10,0x0e,0x01,0x01,0x1e},
	{0x1f,0x04,0x04,0x04,0x04,0x04,0x04},
	{0x11,0x11,0x11,0x11,0x11,0x11,0x0e},
	{0x11,0x11,0x11,0x11,0x0a,0x0a,0x04},
	{0x11,0x11,0x11,0x15,0x15,0x1b,0x11},
	{0x11,0x11,0x0a,0x04,0x0a,0x11,0x11},
	{0x11,0x11,0x0a,0x04,0x04,0x04,0x04},
	{0x1f,0x01,0x02,0x04,0x08,0x10,0x1f},
};

static const u8 *compact_glyph(int ch)
{
	if(ch>='0' && ch<='9'){
		return compact_glyph_digit[ch-'0'];
	}
	if(ch>='a' && ch<='z'){
		ch -= 32;
	}
	if(ch>='A' && ch<='Z'){
		return compact_glyph_alpha[ch-'A'];
	}
	if(ch==':'){
		return compact_glyph_colon;
	}
	if(ch=='/'){
		return compact_glyph_slash;
	}
	if(ch=='-'){
		return compact_glyph_dash;
	}
	if(ch==' '){
		return NULL;
	}
	return compact_glyph_question;
}

static void bitmap_pixel(int x, int y, int color)
{
	if(x<0 || y<0 || x>=fb_w || y>=fb_h){
		return;
	}
	draw_pixel(x, y, color);
}

static void bitmap_box(int x1, int y1, int x2, int y2, int color)
{
	int x, y;

	if(x1<0){ x1 = 0; }
	if(y1<0){ y1 = 0; }
	if(x2>=fb_w){ x2 = fb_w-1; }
	if(y2>=fb_h){ y2 = fb_h-1; }
	if(x1>x2 || y1>y2){
		return;
	}
	for(y=y1; y<=y2; y++){
		for(x=x1; x<=x2; x++){
			draw_pixel(x, y, color);
		}
	}
}

void draw_char(int x, int y, int ch, int color)
{
	const u8 *glyph = compact_glyph(ch);
	int row, col;

	if(glyph==NULL){
		return;
	}
	for(row=0; row<COMPACT_GLYPH_H; row++){
		for(col=0; col<COMPACT_GLYPH_W; col++){
			if(glyph[row] & (0x10>>col)){
				bitmap_pixel(x+col, y+row, color);
			}
		}
	}
}

void draw_text(int x, int y, char *str, int color)
{
	while(*str){
		draw_char(x, y, (int)*str, color);
		x += COMPACT_GLYPH_ADV;
		str++;
	}
}

static void bitmap_segment(int x, int y, int seg, int color)
{
	switch(seg){
		case 0: bitmap_box(x+4,  y+0,  x+23, y+4,  color); break;
		case 1: bitmap_box(x+24, y+4,  x+28, y+25, color); break;
		case 2: bitmap_box(x+24, y+31, x+28, y+52, color); break;
		case 3: bitmap_box(x+4,  y+52, x+23, y+56, color); break;
		case 4: bitmap_box(x+0,  y+31, x+4,  y+52, color); break;
		case 5: bitmap_box(x+0,  y+4,  x+4,  y+25, color); break;
		default: bitmap_box(x+4, y+26, x+23, y+30, color); break;
	}
}

static void bitmap_large_digit(int x, int y, int digit, int color)
{
	static const u8 segs[10] = {
		0x3f, 0x06, 0x5b, 0x4f, 0x66,
		0x6d, 0x7d, 0x07, 0x7f, 0x6f
	};
	u8 mask = segs[digit%10];
	int seg;

	for(seg=0; seg<7; seg++){
		if(mask & (1<<seg)){
			bitmap_segment(x, y, seg, color);
		}
	}
}

static void bitmap_large_colon(int x, int y, int color)
{
	bitmap_box(x+2, y+16, x+6, y+21, color);
	bitmap_box(x+2, y+36, x+6, y+41, color);
}

void bitmap_draw_time_hhmm(int x, int y, int hour, int minute, int color)
{
	bitmap_large_digit(x, y, hour/10, color);
	bitmap_large_digit(x+33, y, hour%10, color);
	bitmap_large_colon(x+65, y, color);
	bitmap_large_digit(x+76, y, minute/10, color);
	bitmap_large_digit(x+109, y, minute%10, color);
}


/******************************************************************************/
#if 0
char *wday_str[] = {
	"ä¸€",
	"äºŒ",
	"ä¸‰",
	"å››",
	"äº”",
	"å…­",
	"æ—¥",
};


static int wday = 0;
void fb_test(void)
{
	memset(fb_bw, 0xff, scr_h*line_bytes);
	if(scr_mode&EPD_BWR){
		memset(fb_rr, 0x00, scr_h*line_bytes);
	}

	draw_rect(0, 0, fb_w-1, fb_h-1, BLACK);
	draw_rect(1, 1, fb_w-2, fb_h-2, BLACK);

#if 0
	for(int i=0; i<3; i++){
		int x = 8+i*38;
		int y = 30;
		draw_rect(x, y, x+29, y+29, BLACK);
		//draw_rect(x+1, y+1, x+29-1, y+29-1, BLACK);
		draw_box(x+2, y+2, x+29-2, y+29-2, i);
	}
#endif

	select_font(0);

	char tbuf[64];
	sprintk(tbuf, "%4då¹´%2dæœˆ%2dæ—¥ æ˜ŸæœŸ%s", 2025, 4, 29, wday_str[wday]);
	draw_text(15, 85, tbuf, BLACK);
	
	wday += 1;
	if(wday==7)
		wday = 0;

	select_font(1);
	sprintk(tbuf, "%02d:%02d", 2+wday, 30+wday);
	draw_text(12, 20, tbuf, BLACK);

	epd_screen_update();
}
#endif

/******************************************************************************/



