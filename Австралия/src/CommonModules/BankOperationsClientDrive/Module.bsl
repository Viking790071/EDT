
// Specifies the text of the divided object state,
// sets the availability of the state control buttons and ReadOnly form flag 
//
Procedure ProcessManualEditFlag(Val Form) Export
	
	Items  = Form.Items;
	
	If Form.ManualChanging = Undefined Then
		Form.ManualEditText = NStr("en = 'The item is created manually. Automatic update is impossible.'; ru = 'Данный элемент был создан вручную. Автоматическое обновление невозможно.';pl = 'Procedura jest tworzona ręcznie. Automatyczna aktualizacja jest niemożliwa.';es_ES = 'El artículo se ha creado manualmente. La actualización automática es imposible.';es_CO = 'El artículo se ha creado manualmente. La actualización automática es imposible.';tr = 'Öğe manuel olarak oluşturuldu. Otomatik güncelleme yapılamaz.';it = 'L''elemento viene creato manualmente. L''aggiornamento automatico è impossibile.';de = 'Der Artikel wird manuell erstellt. Automatische Aktualisierung ist nicht möglich.'");
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = False;
		Form.ReadOnly          = False;
		Items.Parent.Enabled = True;
		Items.Code.Enabled      = True;
	ElsIf Form.ManualChanging = True Then
		Form.ManualEditText = NStr("en = 'Automatic item update is disabled.'; ru = 'Автоматическое обновление элемента невозможно.';pl = 'Automatyczna aktualizacja produktu jest wyłączona.';es_ES = 'La actualización automática de artículos está desactivada.';es_CO = 'La actualización automática de artículos está desactivada.';tr = 'Otomatik öğe güncellemesi devre dışı.';it = 'L''aggiornamento automatico oggetto è disabilitato.';de = 'Die automatische Artikelaktualisierung ist deaktiviert.'");
		
		Items.UpdateFromClassifier.Enabled = True;
		Items.Change.Enabled = False;
		Form.ReadOnly          = False;
		Items.Parent.Enabled = False;
		Items.Code.Enabled      = False;
	Else
		Form.ManualEditText = NStr("en = 'Item is updated automatically.'; ru = 'Элемент обновлен автоматически.';pl = 'Element jest aktualizowany automatycznie.';es_ES = 'Artículo está actualizado automáticamente.';es_CO = 'Artículo está actualizado automáticamente.';tr = 'Ürün otomatik olarak güncellendi.';it = 'Elemento viene aggiornato automaticamente.';de = 'Artikel wird automatisch aktualisiert.'");
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = True;
		Form.ReadOnly          = True;
	EndIf;
	
EndProcedure

// Prompts the user to update from the common data.
// IN case of an affirmative answer, it returns True.
//
Procedure RefreshItemFromClassifier(Val Form, ExecuteUpdate) Export
	
	QuestionText = NStr("en = 'The item data will be replaced with the data from the classifier.
	                    |All manual changes will be lost. Continue?'; 
	                    |ru = 'Данные элемента будут заменены данными из классификатора.
	                    |Все изменения, выполненные вручную, будут потеряны. Продолжить?';
	                    |pl = 'Dane pozycji zostaną zastąpione danymi z klasyfikatora.
	                    |Wszystkie ręczne zmiany zostaną utracone. Kontynuować?';
	                    |es_ES = 'Los datos del artículo se reemplazarán con los datos desde el clasificador.
	                    |Todos los cambios manuales se perderán. ¿Continuar?';
	                    |es_CO = 'Los datos del artículo se reemplazarán con los datos desde el clasificador.
	                    |Todos los cambios manuales se perderán. ¿Continuar?';
	                    |tr = 'Öğe verileri sınıflandırıcıdan gelen verilerle değiştirilecek.
	                    |Tüm manuel değişiklikler kaybolacak. Devam edilsin mi?';
	                    |it = 'I dati dell''elemento saranno sostituiti dai dati del classificatore.
	                    |Tutti le modifiche manuali andranno perse. Continuare?';
	                    |de = 'Die Artikeldaten werden durch die Daten des Klassifikators ersetzt.
	                    |Alle manuellen Änderungen gehen verloren. Fortsetzen?'");
							
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Form", Form);
	AdditionalParameters.Insert("ExecuteUpdate", ExecuteUpdate);
	
	NotifyDescription = New NotifyDescription("DetermineNecessityForDataUpdateFromClassifier", Form, AdditionalParameters);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure
