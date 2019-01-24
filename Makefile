build:
	bundle exec jekyll build

cv:
	cd cv && texi2pdf en.tex

server:
	bundle exec jekyll server --watch --incremental

.PHONY: cv
