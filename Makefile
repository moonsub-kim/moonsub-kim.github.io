compress:
	pngquant --quality 30-50 --verbose --ext .png --force $(dir)/*.png 

unzip:
	7z e $(file)
