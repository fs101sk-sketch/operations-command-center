from pathlib import Path

path = Path('index.html')
text = path.read_text(encoding='utf-8')

def replace_once(old, new, label):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 occurrence, found {count}')
    text = text.replace(old, new, 1)

replace_once(
"  let weeks=[],participants=[],regions=[],imageUrl='',xlsxName='رصيد 2026.xlsx',imageName='1000210257.jpg',loadStatus='idle',loadError='',loadedUserKey='',loadSeq=0;",
"  let weeks=[],participants=[],regions=[],imageUrl='',xlsxName='رصيد 2026.xlsx',imageName='1000210257.jpg',xlsxUrl='',imageSourceUrl='',imageMime='image/jpeg',loadStatus='idle',loadError='',loadedUserKey='',loadSeq=0;",
'variables')

replace_once(
"  function installPayload(payload){if(payload?.schemaVersion!==1||!Array.isArray(payload?.sourceData?.sheets)||typeof payload.xlsxBase64!=='string'||typeof payload.imageBase64!=='string')throw new Error('invalid_private_asset');SOURCE_DATA=payload.sourceData;XLSX_BASE64=payload.xlsxBase64;IMAGE_BASE64=payload.imageBase64;xlsxName=payload.xlsxName||xlsxName;imageName=payload.imageName||imageName;weeks=SOURCE_DATA.sheets[0]?.weeks||[];participants=SOURCE_DATA.sheets.flatMap(sheet=>sheet.rows.filter(row=>row.st==='n').map(row=>({id:'balance-'+sheet.cls+'-'+row.r,classification:sheet.cls,sheet:sheet.n,sourceRow:row.r,sourceSerial:row.sn,name:normalize(row.nn||row.nr),rawName:row.nr,region:normalizeRegion(row.rn||row.rr),rawRegion:row.rr,total:Number(row.calc)||0,weeks:row.w})));regions=[...new Set(participants.map(person=>person.region))].sort((a,b)=>a.localeCompare(b,'ar'));if(imageUrl){URL.revokeObjectURL(imageUrl);imageUrl=''}}",
"  function installPayload(payload){if(payload?.schemaVersion!==1||!Array.isArray(payload?.sourceData?.sheets)||typeof payload.xlsxBase64!=='string'||typeof payload.imageBase64!=='string')throw new Error('invalid_private_asset');SOURCE_DATA=payload.sourceData;XLSX_BASE64=payload.xlsxBase64;IMAGE_BASE64=payload.imageBase64;xlsxName=payload.xlsxName||xlsxName;imageName=payload.imageName||imageName;xlsxUrl=payload.external?.xlsxUrl||'';imageSourceUrl=payload.external?.imageUrl||'';imageMime=payload.external?.imageMime||'image/jpeg';weeks=SOURCE_DATA.sheets[0]?.weeks||[];participants=SOURCE_DATA.sheets.flatMap(sheet=>sheet.rows.filter(row=>row.st==='n').map(row=>({id:'balance-'+sheet.cls+'-'+row.r,classification:sheet.cls,sheet:sheet.n,sourceRow:row.r,sourceSerial:row.sn,name:normalize(row.nn||row.nr),rawName:row.nr,region:normalizeRegion(row.rn||row.rr),rawRegion:row.rr,total:Number(row.calc)||0,weeks:row.w})));regions=[...new Set(participants.map(person=>person.region))].sort((a,b)=>a.localeCompare(b,'ar'));if(imageUrl){URL.revokeObjectURL(imageUrl);imageUrl=''}}",
'installPayload')

replace_once(
"  function clearPayload(){loadSeq++;SOURCE_DATA=null;XLSX_BASE64='';IMAGE_BASE64='';weeks=[];participants=[];regions=[];loadedUserKey='';loadStatus='idle';loadError='';Object.assign(state,{tab:'overview',search:'',classification:'',region:'',type:'',cycle:'',selectedWeek:0});if(imageUrl){URL.revokeObjectURL(imageUrl);imageUrl=''}const modal=document.getElementById('balance-image-modal');if(modal){modal.querySelector('img')?.removeAttribute('src');modal.remove()}const slide=privateSlide();if(slide){const region=slide.querySelector('[data-balance-region]');if(region)region.innerHTML='<option value=\"\">كل المناطق</option>';slide.querySelectorAll('[data-balance-panel]').forEach(panel=>panel.innerHTML='')}}",
"  function clearPayload(){loadSeq++;SOURCE_DATA=null;XLSX_BASE64='';IMAGE_BASE64='';xlsxUrl='';imageSourceUrl='';imageMime='image/jpeg';weeks=[];participants=[];regions=[];loadedUserKey='';loadStatus='idle';loadError='';Object.assign(state,{tab:'overview',search:'',classification:'',region:'',type:'',cycle:'',selectedWeek:0});if(imageUrl){URL.revokeObjectURL(imageUrl);imageUrl=''}const modal=document.getElementById('balance-image-modal');if(modal){modal.querySelector('img')?.removeAttribute('src');modal.remove()}const slide=privateSlide();if(slide){const region=slide.querySelector('[data-balance-region]');if(region)region.innerHTML='<option value=\"\">كل المناطق</option>';slide.querySelectorAll('[data-balance-panel]').forEach(panel=>panel.innerHTML='')}}",
'clearPayload')

replace_once(
"  function imageObjectUrl(){if(!IMAGE_BASE64)return'';if(!imageUrl)imageUrl=URL.createObjectURL(b64Blob(IMAGE_BASE64,'image/jpeg'));return imageUrl}",
"  function imageObjectUrl(){if(!IMAGE_BASE64)return'';if(!imageUrl)imageUrl=URL.createObjectURL(b64Blob(IMAGE_BASE64,imageMime));return imageUrl}",
'imageObjectUrl')

replace_once(
"  function downloadSource(kind){if(!SOURCE_DATA)return;const excel=kind==='xlsx',blob=b64Blob(excel?XLSX_BASE64:IMAGE_BASE64,excel?'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':'image/jpeg'),link=document.createElement('a');link.href=URL.createObjectURL(blob);link.download=excel?xlsxName:imageName;link.click();setTimeout(()=>URL.revokeObjectURL(link.href),1000)}",
"  function downloadSource(kind){if(!SOURCE_DATA)return;const excel=kind==='xlsx',external=excel?xlsxUrl:imageSourceUrl,base64=excel?XLSX_BASE64:IMAGE_BASE64;if(external){try{const target=new URL(external,location.href);if(target.protocol!=='https:'||!['docs.google.com','drive.google.com'].includes(target.hostname))return;window.open(target.href,'_blank','noopener,noreferrer');return}catch{return}}if(!base64)return;const blob=b64Blob(base64,excel?'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':imageMime),link=document.createElement('a');link.href=URL.createObjectURL(blob);link.download=excel?xlsxName:imageName;link.click();setTimeout(()=>URL.revokeObjectURL(link.href),1000)}",
'downloadSource')

replace_once(
'<option value="H">الإسكان + المتخصصة</option></select><select data-balance-cycle>',
'<option value="H">الإسكان + المتخصصة</option><option value="U">غير مصنف</option></select><select data-balance-cycle>',
'unknown type option')

replace_once(
"  function typeMarkup(list){return '<div class=\"balance-type-grid\">'+Object.keys(TYPE_LABELS).filter(code=>code!=='U'&&(!state.type||code===state.type)).map(code=>{let slots=0,units=0;list.forEach(person=>person.weeks.forEach((cell,index)=>{if(cell&&cell[1]===code&&(!state.cycle||String(weeks[index]?.v)===state.cycle)){slots++;units+=Number(cell[0])||0}}));return '<div class=\"balance-type-card\" style=\"--type-color:'+TYPE_COLORS[code]+'\"><strong>'+formatNumber(units)+'</strong><span>'+TYPE_LABELS[code]+' · '+formatNumber(slots)+' خانة نشاط</span></div>'}).join('')+'</div>'}",
"  function typeMarkup(list){return '<div class=\"balance-type-grid\">'+Object.keys(TYPE_LABELS).filter(code=>!state.type||code===state.type).map(code=>{let slots=0,units=0;list.forEach(person=>person.weeks.forEach((cell,index)=>{if(cell&&cell[1]===code&&(!state.cycle||String(weeks[index]?.v)===state.cycle)){slots++;units+=Number(cell[0])||0}}));return '<div class=\"balance-type-card\" style=\"--type-color:'+TYPE_COLORS[code]+'\"><strong>'+formatNumber(units)+'</strong><span>'+TYPE_LABELS[code]+' · '+formatNumber(slots)+' خانة نشاط</span></div>'}).join('')+'</div>'}",
'typeMarkup')


old_source = "  function sourceMarkup(){const stats=SOURCE_DATA.sheets.map(sheet=>'<tr><td>'+esc(sheet.n)+'</td><td>'+formatNumber(sheet.stats.named)+'</td><td>'+formatNumber(sheet.stats.activities)+'</td><td>'+formatNumber(sheet.stats.units)+'</td></tr>').join('');return '<div class=\"balance-quality\">ملاحظة جودة المصدر: رقم 88 مفقود من تسلسل ورقة المتعاونين دون حذف أي اسم، وورقة المتعاقدين تحتوي 43 خانة صف محجوزة بلا أسماء. الصورة المرجعية تمتد إلى 27 أغسطس، بينما آخر فترة معنونة في Excel تنتهي في 20 أغسطس؛ لذلك يبقى Excel هو مصدر الأرقام والصورة مرجعًا بصريًا فقط.</div><div class=\"balance-source-grid\"><article class=\"balance-source-card\"><h3>رصيد 2026.xlsx</h3><p>الملف الأصلي محفوظ كاملًا وقابل للتنزيل. تم استخراج البيانات قراءةً فقط دون تعديل المصنف.</p><div class=\"balance-source-actions\"><button type=\"button\" class=\"primary\" data-balance-download=\"xlsx\">تنزيل Excel الأصلي</button></div><p class=\"balance-hash\">SHA-256: '+SOURCE_DATA.source.sha256+'</p><div class=\"balance-table-wrap\" style=\"max-height:180px\"><table class=\"balance-table\"><thead><tr><th>الورقة</th><th>أسماء</th><th>خانات نشاط</th><th>وحدات</th></tr></thead><tbody>'+stats+'</tbody></table></div></article><article class=\"balance-source-card\"><h3>الصورة المرجعية الأصلية</h3><p>لقطة الرسم المضافة مع الملف. لم تُستخدم لاستبدال بيانات Excel بسبب اختلاف آخر فترة زمنية.</p><div class=\"balance-source-actions\"><button type=\"button\" class=\"primary\" data-balance-image>عرض بالحجم الكامل</button><button type=\"button\" data-balance-download=\"image\">تنزيل الصورة</button></div><img class=\"balance-source-thumb\" data-balance-source-thumb alt=\"الرسم البياني لأعداد المشاركين مع تصنيف الزيارات\"></article></div>'}"
new_source = "  function sourceMarkup(){const stats=SOURCE_DATA.sheets.map(sheet=>'<tr><td>'+esc(sheet.n)+'</td><td>'+formatNumber(sheet.stats.named)+'</td><td>'+formatNumber(sheet.stats.activities)+'</td><td>'+formatNumber(sheet.stats.units)+'</td></tr>').join(''),excelAction=xlsxUrl?'فتح Excel الأصلي':'تنزيل Excel الأصلي',imageAction=imageSourceUrl?'فتح الصورة الأصلية':'تنزيل الصورة';return '<div class=\"balance-quality\">ملاحظة جودة المصدر: رقم 88 مفقود من تسلسل ورقة المتعاونين دون حذف أي اسم، وورقة المتعاقدين تحتوي 43 خانة صف محجوزة بلا أسماء. الصورة المرجعية تمتد إلى 27 أغسطس، بينما آخر فترة معنونة في Excel تنتهي في 20 أغسطس؛ لذلك يبقى Excel هو مصدر الأرقام والصورة مرجعًا بصريًا فقط.</div><div class=\"balance-source-grid\"><article class=\"balance-source-card\"><h3>رصيد 2026.xlsx</h3><p>الملف الأصلي محفوظ كاملًا وقابل للفتح أو التنزيل. تم استخراج البيانات قراءةً فقط دون تعديل المصنف.</p><div class=\"balance-source-actions\"><button type=\"button\" class=\"primary\" data-balance-download=\"xlsx\">'+excelAction+'</button></div><p class=\"balance-hash\">SHA-256: '+SOURCE_DATA.source.sha256+'</p><div class=\"balance-table-wrap\" style=\"max-height:180px\"><table class=\"balance-table\"><thead><tr><th>الورقة</th><th>أسماء</th><th>خانات نشاط</th><th>وحدات</th></tr></thead><tbody>'+stats+'</tbody></table></div></article><article class=\"balance-source-card\"><h3>الصورة المرجعية الأصلية</h3><p>لقطة الرسم المضافة مع الملف. لم تُستخدم لاستبدال بيانات Excel بسبب اختلاف آخر فترة زمنية.</p><div class=\"balance-source-actions\"><button type=\"button\" class=\"primary\" data-balance-image>عرض المعاينة بالحجم الكامل</button><button type=\"button\" data-balance-download=\"image\">'+imageAction+'</button></div><img class=\"balance-source-thumb\" data-balance-source-thumb alt=\"معاينة الرسم البياني لأعداد المشاركين مع تصنيف الزيارات\"></article></div>'}"
replace_once(old_source, new_source, 'sourceMarkup')

old_verify = "  async function verifyPayload(payload){const expected=String(payload?.sourceData?.source?.sha256||'').toLowerCase(),expectedImage=String(payload?.sourceData?.source?.imageSha256||'').toLowerCase();if(!expected||!expectedImage||payload?.schemaVersion!==1||typeof payload.xlsxBase64!=='string'||typeof payload.imageBase64!=='string')throw new Error('asset_integrity_failed');const digest=async(base64,type)=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',await b64Blob(base64,type).arrayBuffer()))].map(value=>value.toString(16).padStart(2,'0')).join(''),[actual,actualImage]=await Promise.all([digest(payload.xlsxBase64,'application/octet-stream'),digest(payload.imageBase64,'image/jpeg')]);if(actual!==expected||actualImage!==expectedImage)throw new Error('asset_integrity_failed');return payload}"
new_verify = r'''  async function verifyPayload(payload){
    const hex=buffer=>[...new Uint8Array(buffer)].map(value=>value.toString(16).padStart(2,'0')).join('');
    const digestBytes=async bytes=>hex(await crypto.subtle.digest('SHA-256',bytes));
    const digestBase64=async(base64,type)=>digestBytes(await b64Blob(base64,type).arrayBuffer());
    if(payload?.schemaVersion===1&&Array.isArray(payload?.sourceData?.sheets)&&typeof payload.xlsxBase64==='string'&&typeof payload.imageBase64==='string'){
      const expected=String(payload.sourceData.source?.sha256||'').toLowerCase(),expectedImage=String(payload.sourceData.source?.imageSha256||'').toLowerCase();
      if(!expected||!expectedImage)throw new Error('asset_integrity_failed');
      const [actual,actualImage]=await Promise.all([digestBase64(payload.xlsxBase64,'application/octet-stream'),digestBase64(payload.imageBase64,'image/jpeg')]);
      if(actual!==expected||actualImage!==expectedImage)throw new Error('asset_integrity_failed');
      return payload;
    }
    if(typeof payload?.payload_gzip_base64!=='string'||typeof payload?.image_base64!=='string'||payload?.payload_encoding!=='gzip+json')throw new Error('invalid_private_asset');
    if(typeof DecompressionStream!=='function')throw new Error('private_asset_unsupported');
    const compressed=b64Blob(payload.payload_gzip_base64,'application/gzip');
    const rawBuffer=await new Response(compressed.stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer();
    const rawHash=await digestBytes(rawBuffer),expectedRaw=String(payload.payload_sha256||'').toLowerCase();
    const previewHash=await digestBase64(payload.image_base64,payload.image_mime||'image/webp'),expectedPreview=String(payload.image_sha256||'').toLowerCase();
    if(!expectedRaw||rawHash!==expectedRaw||!expectedPreview||previewHash!==expectedPreview)throw new Error('asset_integrity_failed');
    const legacy=JSON.parse(new TextDecoder().decode(rawBuffer)),overlay=payload.payload?.typeOverlay||{},classMap={cooperators:'collaborator',contractors:'contractor',visitors:'internal_visitor'},cycleMap={'الزيارة الأولى':1,'الزيارة الثانية':2,'الزيارة الثالث':3,'الزيارة الثالثة':3,'الزيارة الرابعة':4};
    if(legacy?.schemaVersion!==1||!Array.isArray(legacy.categories))throw new Error('invalid_private_asset');
    const sheets=legacy.categories.map(category=>{
      const codes=Array.isArray(overlay[category.id])?overlay[category.id]:[];
      const rows=(category.data||[]).map((row,rowIndex)=>({st:'n',r:rowIndex+(category.id==='visitors'?4:3),sn:row.serial,nr:row.name,nn:row.normalizedName,rr:row.region,rn:row.region,calc:Number(row.total)||0,w:(row.weekly||[]).map((value,weekIndex)=>{const amount=Number(value)||0,type=codes[rowIndex]?.[weekIndex];return amount>0?[amount,type&&type!=='.'?type:'U']:null})}));
      const activities=rows.reduce((sum,row)=>sum+row.w.filter(Boolean).length,0);
      return{n:category.label,cls:classMap[category.id]||category.id,weeks:(category.weeks||[]).map((week,index)=>({i:index+1,l:week.label||'',s:week.startDate||'',e:week.endDate||'',v:cycleMap[week.round]||0,c:'U'})),rows,stats:{named:Number(category.records)||rows.length,activities,units:Number(category.total)||0}};
    });
    payload.schemaVersion=1;
    payload.sourceData={schemaVersion:1,source:{sha256:String(payload.workbook_sha256||legacy.source?.workbookSha256||''),imageSha256:String(payload.image_source_sha256||legacy.source?.imageSha256||''),readOnly:true},sheets};
    payload.xlsxBase64=typeof payload.workbook_base64==='string'?payload.workbook_base64:'';
    payload.imageBase64=payload.image_base64;
    payload.xlsxName=payload.workbook_name||legacy.source?.workbookName||'رصيد 2026.xlsx';
    payload.imageName=payload.image_source_name||legacy.source?.imageName||payload.image_name||'الرسم البياني 2026.jpg';
    payload.external={xlsxUrl:payload.workbook_url||'',imageUrl:payload.image_source_url||'',imageMime:payload.image_mime||'image/webp'};
    return payload;
  }'''
replace_once(old_verify, new_verify, 'verifyPayload')

path.write_text(text, encoding='utf-8')
print(path, path.stat().st_size)
