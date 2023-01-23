compress:
	pngquant --quality 30-50 --verbose --ext .png --force $(dir)/*.png 

rename:
	./rename.sh $(dir)

unzip:
	7z e $(file)
