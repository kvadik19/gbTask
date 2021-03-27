var d = document;
var ontime;

const httpStatus = {'403':'Доступ запрещен', '413':'Файл слишком велик', 
				'502':'Не работает обработчик', '500':'Сбой программы сервера',
				'503':'Сервер временно не может обрабатывать запросы',
				'301':'Ресрурс перемещен',
			};

const mimeTypes = {'ttf':'application/x-font-ttf', 'ttc':'application/x-font-ttf', 'otf':'application/x-font-opentype', 
				'woff':'application/font-woff', 'woff2':'application/font-woff2', 'svg':'image/svg+xml',
				'sfnt':'application/font-sfnt', 'eot':'application/vnd.ms-fontobject' ,
				'tif':'image/tiff', 'tiff':'image/tiff', 'bmp':'image/x-ms-bmp',
				'jpg':'image/jpeg', 'jpeg':'image/jpeg', 'jpe':'image/jpeg', 'png':'image/png', 'gif':'image/gif',
				'zip':'application/zip', 
				};

var doubleClickEvent = new MouseEvent('dblclick', {
		'view': window,
		'bubbles': true,
		'cancelable': true
	});

var responder = createRequestObject();
var flusher = function(e) {
	try {
		if (this.readyState == 4) {
			if (this.status == 200) {
				if ( this.getResponseHeader('Content-Type').match(/javascript/i) ) {
					eval( this.responseText );
				} else if ( typeof(this.hook) == 'function' ) {
					this.hook(this.responseText);
				} else {
// 					console.log(this.response.text);
				} 
				try { document.onreadystatechange() } catch(e) {};
			} else if (this.status >= 500) {
				console.log('Error 5xx '+this.responseText+'\n'+this.getAllResponseHeaders());
			} else {
				console.log("Reading from server:" + this.status);
				this.abort();		// Clean
			}
		}
	} catch( e ) {
	console.log('Processing error: '+ '\n' + e);	//+ this.responseText
// 	console.log(this.responseText);
	// Bugzilla Bug 238559 XMLHttpRequest needs a way to report networking errors
	}
	dime(0);
}

function flush( data, url, hook, nodime ) {		// Flushes data
	let formData = '';
	if ( typeof(data) === 'object' ) {
		Object.keys(data).forEach( k => {
			let val = data[k];
			if ( typeof(data[k]) === 'object' ) val = JSON.stringify(data[k]);
			formData+='&'+encodeURIComponent(k)+'='+encodeURIComponent(val);
		});
		formData = formData.substr(1);
	} else {
		formData = 'data='+encodeURIComponent(data);
	}

	let sender = createRequestObject();
	sender.hook = hook;
	sender.nodime = nodime;
	
	sender.open('POST', url, true);
	sender.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded' );
	sender.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
	sender.onreadystatechange = flusher;
	sender.send( formData );
}		// Flush ends

function createRequestObject() {
	if (typeof XMLHttpRequest === 'undefined') {
		XMLHttpRequest = function() {
			try { return new ActiveXObject("Msxml2.XMLHTTP.6.0"); }
			catch(e) {}
			try { return new ActiveXObject("Msxml2.XMLHTTP.3.0"); }
			catch(e) {}
			try { return new ActiveXObject("Msxml2.XMLHTTP"); }
			catch(e) {}
			try { return new ActiveXObject("Microsoft.XMLHTTP"); }
			catch(e) {}
			throw new Error("This browser does not support XMLHttpRequest.");
		};
	}
	return	new window.XMLHttpRequest();
}

function dime ( flag, parent ) {		// Dim screen for user wait
	if ( !parent ) parent = document.body;
	if ( !document.getElementById('cvr') ) {
		// Mouse click protection layer
		let ctop = createObj('div',{'id':'ctop','className':'dimmer','style.zIndex':1003,
			'innerHTML':'<button onClick="dime(0);responder.abort();document.location.reload();">'
				+'Cancel</button>'});
		let cvr = createObj('div',{'id':'cvr','className':'dimmer','style.zIndex':1000,'style.cursor':'wait'});
		
		let ccnt = createObj('img',{'id':'cvpb','src':'/img/pb-1_32x32.gif','style.position':'fixed',
			'style.top':'50%','style.left':'50%','style.width':'32px','style.height':'32px','style.zIndex':1002});
				// Progress bar animated gif
		cvr.appendChild(ccnt);
		cvr.appendChild(ctop);
		parent.appendChild(cvr);
	}

	if ( flag == 1 ) {
		document.getElementById('cvr').style.display='table-cell';
	} else {
		document.getElementById('cvr').style.display='none';
		clearTimeout( ontime );
	}
	return true;
}		// Dim screen for user wait

Array.prototype.grep = function (tester) {
		let res = [];
		for( let nI=0; nI < this.length; nI++ ) {
			if ( tester(this[nI]) ) {
				res.push( this[nI] );
			}
		}
		return res;
	};

function getCookie(c_name) {
	if (document.cookie.length > 0) {
		let cooks = document.cookie.split(';');
		let re = new RegExp('^\\s*'+c_name);
		let got = cooks.grep( cook => { return cook.match(re)});
		if ( got.length > 0 ) {
			let cook = got[got.length-1];
			return decodeURIComponent( cook.split('=')[1] );
		}
	}
	return '';
};

function setCookie(name, value, options) {		// https://learn.javascript.ru/cookie
	options = options || {};
	let expires = options.expires;
	if (typeof(expires) == 'number' && expires) {
		let d = new Date();
		d.setTime(d.getTime() + expires * 1000);
		expires = options.expires = d;
	}
	if (expires && expires.toUTCString) {
		options.expires = expires.toUTCString();
	}
	value = encodeURIComponent(value);
	let updatedCookie = name + "=" + value;
	for (let propName in options) {
		updatedCookie += "; " + propName;
		let propValue = options[propName];
		if (propValue !== true) {
			updatedCookie += "=" + propValue;
		}
	}
	document.cookie = updatedCookie;
}

document.addEventListener('DOMContentLoaded', function() {

		document.querySelectorAll('.closebox').forEach( b => {
				b.addEventListener('click', function(e) {
						let p = findParentBy(b, function(o) { return o.className.match(/\s*over\-panel/i) });
						p.style.display = 'none';
					});
			});
	});


var uploaderObject = function(params) {
/*
 * Объект-загрузчик файла на сервер.
 * Передаваемые параметры:
 * file	   - объект File (обязателен)
 * url		- строка, указывает куда загружать (обязателен)
 * fieldName  - имя поля, содержащего файл (как если задать атрибут name тегу input)
 * onprogress - функция обратного вызова, вызывается при обновлении данных
 *			  о процессе загрузки, принимает один параметр: состояние загрузки (в процентах)
 * oncopmlete - функция обратного вызова, вызывается при завершении загрузки, принимает два параметра:
 *			  uploaded - содержит true, в случае успеха и false, если возникли какие-либо ошибки;
 *			  data - в случае успеха в него передается ответ сервера
 *			  
 *			  если в процессе загрузки возникли ошибки, то в свойство lastError объекта помещается
 *			  объект ошибки, содержащий два поля: code и text
 */

	if( !(params.file && params.url) ) {
		return false;
	}

	this.xhr = new XMLHttpRequest();
	this.reader = new FileReader();
	this.progress = 0;
	this.uploaded = false;
	this.successful = false;
	this.lastError = false;
	
	let self = this;	
	self.reader.onload = function() {
			self.xhr.upload.addEventListener("progress", function(e) {
				if (e.lengthComputable) {
					self.progress = (e.loaded * 100) / e.total;
					if(params.onprogress instanceof Function) {
						params.onprogress.call(self, Math.round(self.progress));
					}
				}
			}, false);

			self.xhr.upload.addEventListener("load", function(){
				self.progress = 100;
				self.uploaded = true;
			}, false);

			self.xhr.upload.addEventListener("error", function(){			
				self.lastError = {
					code: 1,
					text: 'Error uploading on server'
				};
			}, false);

			self.xhr.onreadystatechange = function () {
				let callbackDefined = params.oncomplete instanceof Function;
				if (this.readyState == 4) {
					if(this.status == 200) {
						if(!self.uploaded) {
							if(callbackDefined) {
								params.oncomplete.call(self, false);
							}
						} else {
							self.successful = true;
							if(callbackDefined) {
								params.oncomplete.call(self, true, this.responseText);
							}
						}
					} else {
						self.lastError = {
							code: this.status,
							text: 'HTTP response code is not OK ('+this.status+' - '+httpStatus[this.status]+')'
						};
						if(callbackDefined) {
							params.oncomplete.call(self, false);
						}
					}
				}
			};

			self.xhr.open("POST", params.url);

			let formData = new FormData();
			formData.append(params.fieldName, params.file, params.file.name);
			for ( let fld in params.formData ) {
				formData.append( fld, params.formData[fld] );
			};
			self.xhr.send(formData);
		};

	self.reader.readAsBinaryString(params.file);
};
