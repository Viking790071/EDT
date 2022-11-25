
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ReadOnly = True;
	
	FieldsCompositionDetails = FieldsCompositionDetails(Object.FieldsComposition);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
	ShowMessageBox(,
		NStr("ru = 'Ключ доступа не следует изменять, так как он сопоставлен с разными объектами.
		           |Чтобы исправить нестандартную проблему следует удалить ключ доступа или
		           |связь с ним в регистрах и выполнить процедуру обновления доступа.'; 
		           |en = 'It is not recommend that you change the access key as it is mapped to various objects.
		           |To resolve a non-standard issue, delete the access key or
		           |a link with it in registers and update access.'; 
		           |pl = 'Klucz dostępu nie należy zmieniać, ponieważ on jest zestawiony z różnymi obiektami.
		           |Aby poprawić nietypowy problem należy usunąć klucz dostępu lub 
		           |związek z nim w rejestrach i wykonać procedurę aktualizacji dostępu.';
		           |es_ES = 'No hay que cambiar la clave de acceso porque está vinculada con varios objetos.
		           |Para corregir un problema no estándar hay que eliminar la clave de acceso o
		           |el vínculo con ella en los registros y realizar el procedimiento de actualización de acceso.';
		           |es_CO = 'No hay que cambiar la clave de acceso porque está vinculada con varios objetos.
		           |Para corregir un problema no estándar hay que eliminar la clave de acceso o
		           |el vínculo con ella en los registros y realizar el procedimiento de actualización de acceso.';
		           |tr = 'Farklı nesnelerle eşleştirildiğinden erişim anahtarı değiştirilmemelidir.
		           |Standart olmayan bir sorunu gidermek için, erişim anahtarını veya 
		           |kayıtlarda onunla bağlantıyı kaldırmanız ve erişim güncelleme işlemini gerçekleştirmeniz gerekir.';
		           |it = 'È sconsigliata la modifica della chiave di accesso, poiché è mappata in diversi oggetti.
		           |Per risolvere un problema non standard, eliminare la chiave di accesso o 
		           |collegarsi con essa per l''accesso a registri e aggiornamenti.';
		           |de = 'Der Zugriffsschlüssel sollte nicht geändert werden, da er verschiedenen Objekten zugeordnet ist.
		           |Um ein nicht standardmäßiges Problem zu beheben, entfernen Sie den Zugriffsschlüssel oder
		           |die Registerkommunikation und führen Sie das Verfahren zur Aktualisierung des Zugriffs durch.'"));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function FieldsCompositionDetails(FieldsContent)
	
	CurrentCount = FieldsContent;
	Details = "";
	
	TabularSectionNumber = 0;
	While CurrentCount > 0 Do
		Balance = CurrentCount - Int(CurrentCount / 16) * 16;
		If TabularSectionNumber = 0 Then
			Details = NStr("ru = 'Шапка'; en = 'Header'; pl = 'Nagłówek';es_ES = 'Encabezado';es_CO = 'Encabezado';tr = 'Üst bilgi';it = 'Intestazione';de = 'Kopfzeile'") + ": " + Balance;
		Else
			Details = Details + ", " + NStr("ru = 'Табличная часть'; en = 'Tabular section'; pl = 'Część tabelaryczna';es_ES = 'Parte de tabla';es_CO = 'Parte de tabla';tr = 'Tablo bölümü';it = 'Sezione tabellare';de = 'Tabellarischer Teil'") + " " + TabularSectionNumber + ": " + Balance;
		EndIf;
		CurrentCount = Int(CurrentCount / 16);
		TabularSectionNumber = TabularSectionNumber + 1;
	EndDo;
	
	Return Details;
	
EndFunction

#EndRegion
