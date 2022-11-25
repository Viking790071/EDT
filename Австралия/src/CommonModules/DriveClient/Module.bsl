#Region ExportProceduresAndFunctions

// Displays a message on filling error.
//
Procedure ShowMessageAboutError(ErrorObject, MessageText, TabularSectionName = Undefined, LineNumber = Undefined, Field = Undefined, Cancel = False) Export
	
	Message = New UserMessage();
	Message.Text = MessageText;
	
	If TabularSectionName <> Undefined Then
		Message.Field = TabularSectionName + "[" + (LineNumber - 1) + "]." + Field;
	ElsIf ValueIsFilled(Field) Then
		Message.Field = Field;
	EndIf;
	
	If ErrorObject <> Undefined Then
		Message.SetData(ErrorObject);
	EndIf;
	
	Message.Message();
	
	Cancel = True;
	
EndProcedure

// Function checks whether it is possible to print receipt on fiscal data recorder.
//
// Parameters:
// Form - ClientApplicationForm - Document form
//
// Returns:
// Boolean - Shows that printing is possible
//
Function CheckPossibilityOfReceiptPrinting(Form, ShowMessageBox = False) Export
	
	CheckPrint = True;
	
	// If object is not posted or modified - execute posting.
	If Not Form.Object.Posted
		OR Form.Modified Then
		
		Try
			If Not Form.Write(New Structure("WriteMode", DocumentWriteMode.Posting)) Then
				CheckPrint = False;
			EndIf;
		Except
			ShowMessageBox = True;
			CheckPrint = False;
		EndTry;
			
	EndIf;
	
	Return CheckPrint;

EndFunction

Procedure OnStart(Parameters) Export
	
	If DriveServerCall.GetConstant("EachGLAccountIsMappedToIncomeAndExpenseItem") 
		And DriveServerCall.GetConstant("EachProfitEstimationGLAccountIsMappedToIncomeAndExpenseItem") Then
		DriveServerCall.ConfigureUserDesktop(Parameters.SettingsModified);
	Else
		OpenForm(
			"DataProcessor.MappingGLAccountsToIncomeAndExpenseItems.Form.Form", , , , , ,
			New NotifyDescription("OnCloseMappingGLAccountsToIncomeAndExpenseItemsForm", DriveClient),
			FormWindowOpeningMode.LockWholeInterface);
	EndIf;
	
EndProcedure

Procedure OnCloseMappingGLAccountsToIncomeAndExpenseItemsForm(Result, Parameters) Export
	
	If Result = True Then
		
		SettingsModified = False;
		DriveServerCall.ConfigureUserDesktop(SettingsModified);
		
		If SettingsModified Then
			RefreshInterface();
		EndIf;
		
	EndIf;
	
EndProcedure

Function GetSelectExchangeRateDateParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("Company", Undefined);
	Parameters.Insert("Currency", Undefined);
	Parameters.Insert("ExchangeRateMethod", Undefined);
	Parameters.Insert("PresentationCurrency", Undefined);
	Parameters.Insert("RateDate", Undefined);
	
	Return Parameters;
	
EndFunction

Procedure OpenSelectExchangeRateDateForm(FormParameters, ParentForm, NotifyDescription) Export
	
	OpenForm("CommonForm.SelectExchangeRateDate", FormParameters, ParentForm, , , , NotifyDescription);
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure updates document state.
//
Procedure RefreshDocumentStatus(Object, DocumentStatus, PictureDocumentStatus, PostingIsAllowed) Export
	
	If Object.Posted Then
		DocumentStatus = "Posted";
		PictureDocumentStatus = 1;
	ElsIf PostingIsAllowed Then
		DocumentStatus = "Not posted";
		PictureDocumentStatus = 0;
	Else
		DocumentStatus = "Recorded";
		PictureDocumentStatus = 3;
	EndIf;
	
EndProcedure

// Function returns weekday presentation.
//
Function GetPresentationOfWeekDay(CalendarWeekDay) Export
	
	WeekDayNumber = WeekDay(CalendarWeekDay);
	If WeekDayNumber = 1 Then
		
		Return NStr("en = 'Mon'; ru = 'Пн';pl = 'Pn';es_ES = 'Lun';es_CO = 'Lun';tr = 'Pzt';it = 'Lun';de = 'Mo'");
		
	ElsIf WeekDayNumber = 2 Then
		
		Return NStr("en = 'Tue'; ru = 'Вт';pl = 'Wt';es_ES = 'Mart';es_CO = 'Mart';tr = 'Sa';it = 'Mar';de = 'Di'");
		
	ElsIf WeekDayNumber = 3 Then
		
		Return NStr("en = 'Wed'; ru = 'Ср';pl = 'Śr';es_ES = 'Miérc';es_CO = 'Miérc';tr = 'Çar';it = 'Mer';de = 'Mi'");
		
	ElsIf WeekDayNumber = 4 Then
		
		Return NStr("en = 'Thu'; ru = 'Чт';pl = 'Cz';es_ES = 'Juev';es_CO = 'Juev';tr = 'Per';it = 'Gio';de = 'Do'");
		
	ElsIf WeekDayNumber = 5 Then
		
		Return NStr("en = 'Fri'; ru = 'Пт';pl = 'Pt';es_ES = 'Viér';es_CO = 'Viér';tr = 'Cu';it = 'Ven';de = 'Fr'");
		
	ElsIf WeekDayNumber = 6 Then
		
		Return NStr("en = 'Sa'; ru = 'Сб';pl = 'Sb';es_ES = 'Sáb';es_CO = 'Sáb';tr = 'Cmt';it = 'Sab';de = 'Sa'");
		
	Else
		
		Return NStr("en = 'Sun'; ru = 'Вс';pl = 'Nd';es_ES = 'Dom';es_CO = 'Dom';tr = 'Paz';it = 'Dom';de = 'So'");
		
	EndIf;
	
EndFunction

// Fills in data structure for opening calendar selection form
//
Function GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen, 
		CloseOnChoice = True, 
		Multiselect = False) Export
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert(
		"CalendarDate", 
			CalendarDateOnOpen
		);
		
	ParametersStructure.Insert(
		"CloseOnChoice", 
			CloseOnChoice
		);
		
	ParametersStructure.Insert(
		"Multiselect", 
			Multiselect
		);
		
	Return ParametersStructure;
	
EndFunction

// Places passed value to ValuesList
// 
Function ValueToValuesListAtClient(Value, ValueList = Undefined, AddDuplicates = False) Export
	
	If TypeOf(ValueList) = Type("ValueList") Then
		
		If AddDuplicates Then
			
			ValueList.Add(Value);
			
		ElsIf ValueList.FindByValue(Value) = Undefined Then
			
			ValueList.Add(Value);
			
		EndIf;
		
	Else
		
		ValueList = New ValueList;
		ValueList.Add(Value);
		
	EndIf;
	
	Return ValueList;
	
EndFunction

// Fills in the values list Receiver from the values list Source
//
Procedure FillListByList(Source,Receiver) Export

	Receiver.Clear();
	For Each ListIt In Source Do
		Receiver.Add(ListIt.Value, ListIt.Presentation);
	EndDo;

EndProcedure

Function CheckGetSelectedRefsInList(List) Export
	
	RefsArray = New Array;
	
	For Count = 0 To List.SelectedRows.Count() - 1 Do
		If TypeOf(List.SelectedRows[Count]) <> Type("DynamicListGroupRow") Then
			RefsArray.Add(List.SelectedRows[Count]);
		EndIf;
	EndDo;
	
	If RefsArray.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'The command cannot be executed for the specified object'; ru = 'Команда не моет быть выполнена для указанного объекта.';pl = 'To polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado';es_CO = 'No se puede ejecutar el comando para el objeto especificado';tr = 'Komut, belirtilen nesne için yürütülemiyor';it = 'Il comando non può essere eseguito per l''oggetto specificato';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden'"));
	EndIf;
	
	Return RefsArray;
	
EndFunction

Procedure CalculateVATAmount(CurrentData, AmountIncludesVAT) Export 
    
	VATRate = DriveReUse.GetVATRateValue(CurrentData.VATRate);
	
	If AmountIncludesVAT Then
		CurrentData.VATAmount = CurrentData.Amount - (CurrentData.Amount) / ((VATRate + 100) / 100);
	Else
		CurrentData.VATAmount = CurrentData.Amount * VATRate / 100;
	EndIf;
	
EndProcedure

Function GetCostAmount(Document, CurrentData) Export
	
	StructureData = New Structure;
	StructureData.Insert("Document",		Document);
	StructureData.Insert("Product",			CurrentData.Products);
	StructureData.Insert("Characteristic",	CurrentData.Characteristic);
	StructureData.Insert("Batch",			CurrentData.Batch);
	StructureData.Insert("Quantity",		CurrentData.Quantity);
	
	Return DriveServerCall.GetCostAmount(StructureData);
	
EndFunction

Procedure ProcessDateChange(Form,
	ProcedureName = "Attachable_ProcessDateChange", AttributeName = "DocumentDate") Export
	
	Object = Form.Object;
	DocumentDate = Form[AttributeName];
	
	If Object.Date <> DocumentDate Then
		
		DateDiff = 0;
		If Not IsBlankString(Object.Number) Then
			DateDiff = DriveServerCall.CheckDocumentNumber(Object.Ref, Object.Date, DocumentDate);
		EndIf;
		
		If DateDiff <> 0 Then
			
			DocumentParameters = New Structure;
			DocumentParameters.Insert("Form", Form);
			DocumentParameters.Insert("AttributeName", AttributeName);
			DocumentParameters.Insert("ProcedureName", ProcedureName);
			
			QuestionText = NStr("en = 'You have changed the document date. This date falls into another document numbering period.
				|The current document number will be cleared and a new one will be assigned automatically upon saving the document.
				|Do you want to continue?'; 
				|ru = 'Вы изменили дату документа. Новая дата приходится на другой период нумерации документов.
				|Текущий номер документа будет очищен и автоматически заменен на новый при записи документа.
				|Продолжить?';
				|pl = 'Zmieniłeś/aś datę dokumentu. Ta data przypada na inny okres numeracji dokumentów.
				|Bieżący numer dokumentu zostanie wyczyszczony i nowy numer zostanie automatycznie przypisany podczas zapisywania dokumentu.
				|Czy chcesz kontynuować?';
				|es_ES = 'Ha cambiado la fecha del documento. Esta fecha cae en otro periodo de numeración del documento.
				| El número de documento actual se borrará y se asignará uno nuevo automáticamente al guardar el documento.
				|¿Quiere continuar?';
				|es_CO = 'Ha cambiado la fecha del documento. Esta fecha cae en otro periodo de numeración del documento.
				| El número de documento actual se borrará y se asignará uno nuevo automáticamente al guardar el documento.
				|¿Quiere continuar?';
				|tr = 'Belge tarihini değiştirdiniz. Bu tarih başka bir belge numaralandırma dönemine denk geliyor.
				|Belge kaydedildiğinde mevcut belge numarası silinerek otomatik olarak yeni bir numara atanacak.
				|Devam etmek istiyor musunuz?';
				|it = 'La data del documento è stata modificata. Questa data rientra in un altro periodo di numerazione del documento. 
				|Il numero del documento corrente sarà cancellato e ne sarà assegnato un altro automaticamente durante il salvataggio del documento. 
				|Continuare?';
				|de = 'Sie haben das Dokumentendatum geändert. Dieses Datum liegt im Nummernzeitraum eines anderen Dokumentes.
				|Die laufende Dokumentennummer wird gelöscht und das Neue beim Speichern des Dokumentes wird automatisch zugewiesen.
				|Möchten Sie fortfahren?'");
			
			NotifyDescription = New NotifyDescription("ProcessDateDiffQueryBox", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			If IsBlankString(ProcedureName) Then
				Form[AttributeName] = Object.Date;
			Else
				Form.AttachIdleHandler(ProcedureName, 0.2, True);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region SplitLine
	
// Handler command "Split line".
//
//	Parameters:
//		TableDocument - FormDataCollection
//		ItemForm - FormTable
//		NotifyAfterSplit - NotifyDescription
//		ParametersOfSplitLine - Structure
//
Procedure SplitLineOfTable(TableDocument, ItemForm, NotifyAfterSplit = Undefined, ParametersOfSplitLine = Undefined) Export
	
	If ParametersOfSplitLine = Undefined Then
	
		ParametersOfSplitLine = New Structure;
		ParametersOfSplitLine.Insert("NameFieldQuantity", "Quantity");
		ParametersOfSplitLine.Insert("Title", NStr("en = 'Enter product quantity for new row'; ru = 'Введите количество номенклатуры для новой строки';pl = 'Wprowadź ilość produktu dla nowego wiersza';es_ES = 'Introducir la cantidad del producto para la nueva fila';es_CO = 'Introducir la cantidad del producto para la nueva fila';tr = 'Yeni satır için ürün miktarı girin';it = 'Inserire quantità articolo per nuova riga';de = 'Geben Sie die Produktmenge für eine neue Reihe'"));
		ParametersOfSplitLine.Insert("Quantity", Undefined);
	
	EndIf; 
	
	
	CurrentLine		= ItemForm.CurrentData;
	IsNumberEntered = True;
	
	If CurrentLine = Undefined Then
		TextMessage = NStr("en = 'First, select a row with a product. Then try again.'; ru = 'Сначала выберите строку с номенклатурой. Затем повторите попытку.';pl = 'Najpierw, wybierz wiersz z produktem. Następnie spróbuj ponownie.';es_ES = 'Primero, seleccione una fila con un producto. A continuación, inténtelo de nuevo.';es_CO = 'Primero, seleccione una fila con un producto. A continuación, inténtelo de nuevo.';tr = 'Önce, ürün olan bir satır seçip tekrar deneyin.';it = 'Innanzitutto, selezionare una riga con un articolo. Poi riprovare.';de = 'Zuerst wählen Sie eine Reihe mit einem Produkt aus. Dann versuchen Sie erneut.'");
		ShowMessageBox( , TextMessage);
		If NotifyAfterSplit <> Undefined Then
			ExecuteNotifyProcessing(NotifyAfterSplit, Undefined);
		EndIf; 
		Return;
	ElsIf CurrentLine[ParametersOfSplitLine.NameFieldQuantity] = 0 Then
		TextMessage = NStr("en = 'Cannot split the selected row. Quantity is required.'; ru = 'Не удалось разделить выбранную строку. Поле ""Количество"" не заполнено.';pl = 'Nie można rozdzielić wybranego wiersza. Wymagana jest ilość.';es_ES = 'No se puede dividir la fila seleccionada. Se requiere una cantidad.';es_CO = 'No se puede dividir la fila seleccionada. Se requiere una cantidad.';tr = 'Seçili satır bölünemiyor. Miktar gerekli.';it = 'Impossibile dividere la riga selezionata. Richiesta quantità.';de = 'Fehler beim Spalten der ausgewählten Reihe. Menge ist nötig.'");
		ShowMessageBox(,TextMessage);
		If NotifyAfterSplit <> Undefined Then
			ExecuteNotifyProcessing(NotifyAfterSplit, Undefined);
		EndIf; 
		Return;
	EndIf;
	
	If CurrentLine[ParametersOfSplitLine.NameFieldQuantity] <> 0 Then
		
		Quantity = ?(CurrentLine[ParametersOfSplitLine.NameFieldQuantity] = 0, 0, Undefined);
		
		If Quantity = Undefined Then
			SplitLineOfTableInputNumber(TableDocument, ItemForm, NotifyAfterSplit, ParametersOfSplitLine);
			Return;
		EndIf;
		
	Else
		
		Quantity = 0;
		
	EndIf;
	
	SplitLineOfTableAddingLine(TableDocument, ItemForm, Quantity, NotifyAfterSplit, ParametersOfSplitLine);
	
EndProcedure

Procedure SplitLineOfTableInputNumber(TableDocument, ItemForm, NotifyAfterSplit, ParametersOfSplitLine)
	
	CurrentLine		= ItemForm.CurrentData;
	
	If ParametersOfSplitLine.Quantity = Undefined Then
		Quantity = CurrentLine[ParametersOfSplitLine.NameFieldQuantity];
	Else
		Quantity = ParametersOfSplitLine.Quantity;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("TableDocument",		TableDocument);
	AdditionalParameters.Insert("ItemForm",				ItemForm);
	AdditionalParameters.Insert("NotifyAfterSplit",		NotifyAfterSplit);
	AdditionalParameters.Insert("ParametersOfSplitLine",ParametersOfSplitLine);
	
	Notify = New NotifyDescription(
		"SplitLineOfTableAfterInputNumber", 
		ThisObject,
		AdditionalParameters);
	ShowInputNumber(Notify, Quantity, ParametersOfSplitLine.Title, 15, 3);

EndProcedure

Procedure SplitLineOfTableAfterInputNumber(Quantity, AdditionalParameters) Export
	
	TableDocument			= AdditionalParameters.TableDocument;
	ItemForm				= AdditionalParameters.ItemForm;
	NotifyAfterSplit		= AdditionalParameters.NotifyAfterSplit;
	ParametersOfSplitLine	= AdditionalParameters.ParametersOfSplitLine;
	
	CurrentLine		= ItemForm.CurrentData;
	
	IsNumberEntered = (Quantity <> Undefined);
	
	If Not IsNumberEntered Then
		If NotifyAfterSplit <> Undefined Then
			ExecuteNotifyProcessing(NotifyAfterSplit, Undefined);
		EndIf;
		Return;
	ElsIf Quantity = 0 Then
		TextMessage = NStr("en = 'The quantity in the new row cannot be 0.'; ru = 'Количество в новой строке не может быть равно 0.';pl = 'Ilość w nowym wierszu nie może być równa 0.';es_ES = 'La cantidad en la nueva fila no puede ser 0.';es_CO = 'La cantidad en la nueva fila no puede ser 0.';tr = 'Yeni satırdaki miktar 0 olamaz.';it = 'La quantità nella nuova riga non può essere 0.';de = 'Die Menge in der neuen Reihe kann nicht 0 sein.'");
		Notify = New NotifyDescription("SplitLineOfTableAfterMessage", ThisObject, AdditionalParameters);
		ShowMessageBox(Notify, TextMessage);
		Return;
	ElsIf CurrentLine[ParametersOfSplitLine.NameFieldQuantity] >= 0
		And Quantity < 0 Then
		TextMessage = NStr("en = 'The quantity in the new row cannot be a negative number.'; ru = 'Количество в новой строке не может быть отрицательным числом.';pl = 'Ilość w nowym wierszu nie może być liczbą ujemną.';es_ES = 'La cantidad en la nueva fila no puede ser un número negativo.';es_CO = 'La cantidad en la nueva fila no puede ser un número negativo.';tr = 'Yeni satırdaki miktar negatif bir sayı olamaz.';it = 'La quantità nella nuova riga non può essere un numero negativo.';de = 'Die Menge in der neuen Reihe kann keine negative Zahl sein.'");
		Notify = New NotifyDescription("SplitLineOfTableAfterMessage", ThisObject, AdditionalParameters);
		ShowMessageBox(Notify, TextMessage);
		Return;
	ElsIf CurrentLine[ParametersOfSplitLine.NameFieldQuantity] <= 0
		And Quantity > 0 Then
		TextMessage = NStr("en = 'The quantity in the new row cannot be a positive number.'; ru = 'Количество в новой строке не может быть положительным числом.';pl = 'Ilość w nowym wierszu nie może być liczbą dodatnią.';es_ES = 'La cantidad en la nueva fila no puede ser un número positivo.';es_CO = 'La cantidad en la nueva fila no puede ser un número positivo.';tr = 'Yeni satırdaki miktar pozitif bir sayı olamaz.';it = 'La quantità nella nuova riga non può essere un numero positivo.';de = 'Die Menge in der neuen Reihe kann keine positive Zahl sein.'");
		Notify = New NotifyDescription("SplitLineOfTableAfterMessage", ThisObject, AdditionalParameters);
		ShowMessageBox(Notify, TextMessage);
		Return;
	ElsIf CurrentLine[ParametersOfSplitLine.NameFieldQuantity] >= 0
		And Quantity >  CurrentLine[ParametersOfSplitLine.NameFieldQuantity] Then
		TextMessage = NStr("en = 'The quantity in the new row cannot be greater than the quantity in the row selected to split.'; ru = 'Количество в новой строке не может быть больше количества в строке, выбранной для разделения.';pl = 'Ilość w nowym wierszu nie może być większa niż ilość w wierszu, wybranym do rozdzielenia.';es_ES = 'La cantidad en la nueva fila no puede ser mayor que la cantidad en la fila seleccionada para dividir.';es_CO = 'La cantidad en la nueva fila no puede ser mayor que la cantidad en la fila seleccionada para dividir.';tr = 'Yeni satırdaki miktar bölünmek üzere seçilen satırdaki miktardan büyük olamaz.';it = 'La quantità nella nuova riga non può essere maggiore della quantità nella riga selezionata da dividere.';de = 'Die Menge in der neuen Reihe kann die Menge in der für Spalten ausgewählten Reihe nicht überschreiten.'");
		Notify = New NotifyDescription("SplitLineOfTableAfterMessage", ThisObject, AdditionalParameters);
		ShowMessageBox(Notify, TextMessage);
		Return;
	ElsIf CurrentLine[ParametersOfSplitLine.NameFieldQuantity] <= 0
		And Quantity < CurrentLine[ParametersOfSplitLine.NameFieldQuantity] Then
		TextMessage = NStr("en = 'The quantity in the new row cannot be less than the quantity in the row selected to split.'; ru = 'Количество в новой строке не может быть меньше количества в строке, выбранной для разделения.';pl = 'Ilość w nowym wierszu nie może być mniejsza niż ilość w wierszu, wybranym do rozdzielenia.';es_ES = 'La cantidad en la nueva fila no puede ser menor que la cantidad en la fila seleccionada para dividir.';es_CO = 'La cantidad en la nueva fila no puede ser menor que la cantidad en la fila seleccionada para dividir.';tr = 'Yeni satırdaki miktar bölünmek üzere seçilen satırdaki miktardan küçük olamaz.';it = 'La quantità nella nuova riga non può essere minore della quantità nella riga selezionata da dividere.';de = 'Die Menge in der neuen Reihe kann nicht unter der Menge in der für Spalten ausgewählten Reihe legen.'");
		Notify = New NotifyDescription("SplitLineOfTableAfterMessage", ThisObject, AdditionalParameters);
		ShowMessageBox(Notify, TextMessage);
		Return;
	ElsIf Quantity =  CurrentLine[ParametersOfSplitLine.NameFieldQuantity] Then
		TextMessage = NStr("en = 'The quantity in the new row cannot match the quantity in the row selected to split.'; ru = 'Количество в новой строке не может совпадать с количеством в строке, выбранной для разделения.';pl = 'Ilość w nowym wierszu nie odpowiadać ilości w wierszu, wybranym do rozdzielenia.';es_ES = 'La cantidad en la nueva fila no puede coincidir con la cantidad en la fila seleccionada para dividir.';es_CO = 'La cantidad en la nueva fila no puede coincidir con la cantidad en la fila seleccionada para dividir.';tr = 'Yeni satırdaki miktar bölünmek üzere seçilen satırdaki miktar ile aynı olamaz.';it = 'La quantità nella nuova riga non può essere corrispondente alla quantità nella riga selezionata da dividere.';de = 'Die Menge in der neuen Reihe kann nicht mit der Menge in der für Spalten ausgewählten Reihe gleich sein.'");
		Notify = New NotifyDescription("SplitLineOfTableAfterMessage", ThisObject, AdditionalParameters);
		ShowMessageBox(Notify, TextMessage);
		Return;
	EndIf;
	
	SplitLineOfTableAddingLine(TableDocument, ItemForm, Quantity, NotifyAfterSplit, ParametersOfSplitLine);
	
EndProcedure

Procedure SplitLineOfTableAfterMessage(AdditionalParameters) Export
	
	TableDocument			= AdditionalParameters.TableDocument;
	ItemForm				= AdditionalParameters.ItemForm;
	NotifyAfterSplit		= AdditionalParameters.NotifyAfterSplit;
	ParametersOfSplitLine	= AdditionalParameters.ParametersOfSplitLine;
	
	SplitLineOfTableInputNumber(TableDocument, ItemForm, NotifyAfterSplit, ParametersOfSplitLine);
	
EndProcedure

Procedure SplitLineOfTableAddingLine(TableDocument, ItemForm, Quantity, NotifyAfterSplit, ParametersOfSplitLine)
	
	CurrentLine		= ItemForm.CurrentData;
	
	IndexCurrentLine	= TableDocument.IndexOf(CurrentLine);
	NewLine				= TableDocument.Insert(IndexCurrentLine + 1);
	FillPropertyValues(NewLine, CurrentLine);
	
	NewLine[ParametersOfSplitLine.NameFieldQuantity]	= Quantity;
	CurrentLine[ParametersOfSplitLine.NameFieldQuantity]	= CurrentLine[ParametersOfSplitLine.NameFieldQuantity]
		- NewLine[ParametersOfSplitLine.NameFieldQuantity];
	
	If NotifyAfterSplit <> Undefined Then
		ExecuteNotifyProcessing(NotifyAfterSplit, NewLine);
	EndIf;
	
	ItemForm.CurrentRow	= NewLine.GetID();
	
EndProcedure

#EndRegion

#EndRegion

#Region ProceduresForWorkWithSubordinateTabularSections

// Procedure adds connection key to tabular section.
//
// Parameters:
//  DocumentForm - ClientApplicationForm, contains a
//                 document form attributes of which are processed by the procedure
//
Procedure AddConnectionKeyToTabularSectionLine(DocumentForm) Export

	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	TabularSectionRow.ConnectionKey = CreateNewLinkKey(DocumentForm);		
        
EndProcedure

// Procedure adds connection key to the subordinate tabular section.
//
// Parameters:
//  DocumentForm - ClientApplicationForm contains a
//                 document form attributes
// of which are processed by the SubordinateTabularSectionName procedure - String that contains the
//                 subordinate tabular section name.
//
Procedure AddConnectionKeyToSubordinateTabularSectionLine(DocumentForm, SubordinateTabularSectionName) Export
	
	SubordinateTbularSection = DocumentForm.Items[SubordinateTabularSectionName];
	
	StringSubordinateTabularSection = SubordinateTbularSection.CurrentData;
	
	If StringSubordinateTabularSection = Undefined Then
		Return;
	EndIf;
	
	StringSubordinateTabularSection.ConnectionKey = SubordinateTbularSection.RowFilter["ConnectionKey"];
	
	FilterStr = New FixedStructure("ConnectionKey", SubordinateTbularSection.RowFilter["ConnectionKey"]);
	DocumentForm.Items[SubordinateTabularSectionName].RowFilter = FilterStr;

EndProcedure

// Procedure prohibits to add new row if row in the main tabular section is not selected.
//
// Parameters:
//  DocumentForm - ClientApplicationForm contains a
//                 document form attributes
// of which are processed by the SubordinateTabularSectionName procedure - String that contains the
//                 subordinate tabular section name.
//
Function BeforeAddToSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export

	If DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData = Undefined Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Row of the main tabular section is not selected.'; ru = 'Не выбрана строка основной табличной части!';pl = 'Nie wybrano wiersza głównej sekcji tabelarycznej.';es_ES = 'Fila de la principal sección tabular no está seleccionada.';es_CO = 'Fila de la principal sección tabular no está seleccionada.';tr = 'Ana sekme bölümünün sırası seçilmemiş.';it = 'La riga della tabella sezione principale non è selezionato.';de = 'Zeile des tabellarischen Hauptabschnitts ist nicht ausgewählt.'");
		Message.Message();
		Return True;
	Else
		Return False;
	EndIf;
		
EndFunction

// Procedure deletes rows from the subordinate tabular section.
//
// Parameters:
//  DocumentForm - ClientApplicationForm contains a
//                 document form attributes
// of which are processed by the SubordinateTabularSectionName procedure - String that contains the
//                 subordinate tabular section name.
//
Procedure DeleteRowsOfSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export

	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
	SubordinateTbularSection = DocumentForm.Object[SubordinateTabularSectionName];
   	
    SearchResult = SubordinateTbularSection.FindRows(New Structure("ConnectionKey", TabularSectionRow.ConnectionKey));
	For Each SearchString In  SearchResult Do
		IndexOfDeletion = SubordinateTbularSection.IndexOf(SearchString);
		SubordinateTbularSection.Delete(IndexOfDeletion);
	EndDo;
	
EndProcedure

// Procedure creates a new key of links for tables.
//
// Parameters:
//  DocumentForm - ClientApplicationForm, contains a
//                 document form whose attributes are processed by the procedure.
//
Function CreateNewLinkKey(DocumentForm) Export

	ValueList = New ValueList;
	
	TabularSection = DocumentForm.Object[DocumentForm.TabularSectionName];
	For Each TSRow In TabularSection Do
        ValueList.Add(TSRow.ConnectionKey);
	EndDo;

    If ValueList.Count() = 0 Then
		ConnectionKey = 1;
	Else
		ValueList.SortByValue();
		ConnectionKey = ValueList.Get(ValueList.Count() - 1).Value + 1;
	EndIf;

	Return ConnectionKey;

EndFunction

// Procedure sets the filter on a subordinate tabular section.
//
Procedure SetFilterOnSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export
	
	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
	If TabularSectionRow = Undefined Then
		Return;
	EndIf; 
	
	FilterStr = New FixedStructure("ConnectionKey", DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData.ConnectionKey);
	DocumentForm.Items[SubordinateTabularSectionName].RowFilter = FilterStr;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfListFormAndCounterpartiesCatalogSelection

// Function checks whether positioning on the row activation is correct.
//
Function PositioningIsCorrect(Form) Export
	
	TypeGroup = Type("DynamicListGroupRow");
		
	If TypeOf(Form.Items.List.CurrentRow) <> TypeGroup AND ValueIsFilled(Form.Items.List.CurrentRow) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Fills in the footer label: Selection basis of the Counterparties catalog.
//
Procedure FillBasisRow(Form) Export
	
	Basis = Form.Bases.FindRows(New Structure("Counterparty", Form.Items.List.CurrentRow));
	If Basis.Count() = 0 Then
		Form.ChoiceBasis = "";
	Else
		Form.ChoiceBasis = Basis[0].Basis;
	EndIf;
	
EndProcedure

// Procedure restores list display after a fulltext search.
//
Procedure RecoverListDisplayingAfterFulltextSearch(Form) Export
	
	If String(Form.Items.List.Representation) <> Form.ViewModeBeforeFulltextSearchApplying Then
		If Form.ViewModeBeforeFulltextSearchApplying = "Hierarchical list" Then
			Form.Items.List.Representation = TableRepresentation.HierarchicalList;
		ElsIf Form.ViewModeBeforeFulltextSearchApplying = "Tree" Then
			Form.Items.List.Representation = TableRepresentation.Tree;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormsProceduresInformationPanel

// Processes a row activation event of the document list.
//
Procedure InfoPanelProcessListRowActivation(Form, InfPanelParameters, ListName = "") Export
	
	If ListName = "" Then
		CurrentDataOfList = Form.Items.List.CurrentData;
	Else
		CurrentDataOfList = Form.Items[ListName].CurrentData;
	EndIf;
	
	If CurrentDataOfList <> Undefined
		AND CurrentDataOfList.Property(InfPanelParameters.CIAttribute) Then
		
		CICurrentAttribute = CurrentDataOfList[InfPanelParameters.CIAttribute];
		
		If Form.ReferenceInformation <> CICurrentAttribute Then
			
			If ValueIsFilled(CICurrentAttribute) Then
				
				IPData = DriveServer.InfoPanelGetData(CICurrentAttribute, InfPanelParameters);
				InfoPanelFill(Form, InfPanelParameters, IPData);
				
				Form.ReferenceInformation = CICurrentAttribute;
				
			Else
				
				InfoPanelFill(Form, InfPanelParameters);
				
			EndIf;
			
		EndIf;
		
	Else
		
		InfoPanelFill(Form, InfPanelParameters);
		
	EndIf;
	
EndProcedure

// Procedure fills in data of the list info panel.
//
Procedure InfoPanelFill(Form, InfPanelParameters, IPData = Undefined)
	
	If IPData = Undefined Then
	
		Form.ReferenceInformation = Undefined;
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation = "";
			Form.CounterpartyInformationES = "";
			Form.CounterpartyFaxInformation = "";
			
			Form.CounterpartyFactAddressInformation = "";
			If Form.Items.Find("InformationCounterpartyShippingAddress") <> Undefined
				OR Form.Items.Find("DetailsListCounterpartyShippingAddress") <> Undefined Then
				
				Form.InformationCounterpartyShippingAddress = "";
				
			EndIf;
			Form.CounterpartyLegalAddressInformation = "";
			
			Form.InformationCounterpartyPostalAddress = "";
			Form.InformationCounterpartyAnotherInformation = "";
			
			// StatementOfAccount.
			If InfPanelParameters.Property("StatementOfAccount") Then
				
				Form.CounterpartyDebtInformation = 0;
				Form.OurDebtInformation = 0;
				
			EndIf;
			
		EndIf;
		
		// Contacts contact information.
		If InfPanelParameters.Property("ContactPerson") Then
			
			Form.InformationContactPhone = "";
			Form.ContactPersonESInformation = "";
			
		EndIf;
		
	Else
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation 	= IPData.Phone;
			Form.CounterpartyInformationES 		= IPData.E_mail;
			Form.CounterpartyFaxInformation 		= IPData.Fax;
			
			Form.CounterpartyFactAddressInformation = IPData.RealAddress;
			If Form.Items.Find("InformationCounterpartyShippingAddress") <> Undefined
				OR Form.Items.Find("DetailsListCounterpartyShippingAddress") <> Undefined Then
				
				Form.InformationCounterpartyShippingAddress = IPData.ShippingAddress;
				
			EndIf;
			Form.CounterpartyLegalAddressInformation 	= IPData.LegAddress;
			
			Form.InformationCounterpartyPostalAddress 	= IPData.MailAddress;
			Form.InformationCounterpartyAnotherInformation 	= IPData.OtherInformation;
			
			// StatementOfAccount.
			If InfPanelParameters.Property("StatementOfAccount") Then
				
				Form.CounterpartyDebtInformation = IPData.Debt;
				Form.OurDebtInformation 		= IPData.OurDebt;
				
			EndIf;
			
		EndIf;
		
		// Contacts contact information.
		If InfPanelParameters.Property("ContactPerson") Then
			
			Form.InformationContactPhone 	= IPData.CLPhone;
			Form.ContactPersonESInformation 		= IPData.ClEmail;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region DiscountCards

// Processes a row activation event of the document list.
//
Procedure DiscountCardsInformationPanelHandleListRowActivation(Form, InfPanelParameters) Export
	
	CurrentDataOfList = Form.Items.List.CurrentData;
	
	If CurrentDataOfList <> Undefined
		AND CurrentDataOfList.Property(InfPanelParameters.CIAttribute) Then
		
		CICurrentAttribute = CurrentDataOfList[InfPanelParameters.CIAttribute];
		
		If Form.ReferenceInformation <> InfPanelParameters.DiscountCard Then
			
			If ValueIsFilled(InfPanelParameters.DiscountCard) Then
				
				IPData = DriveServer.InfoPanelGetData(CICurrentAttribute, InfPanelParameters);
				DiscountCardsInfoPanelFill(Form, InfPanelParameters, IPData);
				
				Form.ReferenceInformation = CICurrentAttribute;
				
			Else
				
				DiscountCardsInfoPanelFill(Form, InfPanelParameters);
				
			EndIf;
			
		EndIf;
		
	Else
		
		DiscountCardsInfoPanelFill(Form, InfPanelParameters);
		
	EndIf;
	
EndProcedure

// Procedure fills in data of the list info panel.
//
Procedure DiscountCardsInfoPanelFill(Form, InfPanelParameters, IPData = Undefined)
	
	If IPData = Undefined Then
	
		Form.ReferenceInformation = Undefined;
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation = "";
			Form.CounterpartyInformationES = "";
			Form.InformationDiscountPercentOnDiscountCard = "";
			Form.InformationSalesAmountOnDiscountCard = "";
			
		EndIf;
		
	Else
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation 				= IPData.Phone;
			Form.CounterpartyInformationES 					= IPData.E_mail;
			Form.InformationDiscountPercentOnDiscountCard 	= IPData.DiscountPercentByDiscountCard;
			Form.InformationSalesAmountOnDiscountCard	= IPData.SalesAmountOnDiscountCard;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region SsmSubsystemsProceduresAndFunctions

// Procedure inputs default expenses invoice while selecting
// Earnings in the document tabular section.
//
// Parameters:
//  DocumentForm - ClientApplicationForm, contains a
//                 document form whose attributes are processed by the procedure.
//
Procedure PutExpensesGLAccountByDefault(DocumentForm, StructuralUnit = Undefined) Export
	
	DataCurrentRows = DocumentForm.Items.EarningsDeductions.CurrentData;
	
	ParametersStructure = New Structure("GLExpenseAccount, TypeOfAccount");
	ParametersStructure.Insert("EarningAndDeductionType", DataCurrentRows.EarningAndDeductionType);
	ParametersStructure.Insert("StructuralUnit", StructuralUnit);
	
	If ValueIsFilled(DataCurrentRows.EarningAndDeductionType) Then
		
		DriveServer.GetEarningKindGLExpenseAccount(ParametersStructure);
		DataCurrentRows.GLExpenseAccount = ParametersStructure.GLExpenseAccount;
		
	EndIf;
	
	If DataCurrentRows.Property("TypeOfAccount") Then
		
		DataCurrentRows.TypeOfAccount = ParametersStructure.TypeOfAccount;
		
	EndIf;
	
EndProcedure

// Procedure sets the registration period to of the beginning of month.
// It also updates period label on form
Procedure OnChangeRegistrationPeriod(SentForm) Export
	
	If Find(SentForm.FormName, "DocumentJournal") > 0 
		OR Find(SentForm.FormName, "ReportForm") Then
		SentForm.RegistrationPeriod 				= BegOfMonth(SentForm.RegistrationPeriod);
		SentForm.RegistrationPeriodPresentation 	= Format(SentForm.RegistrationPeriod, "DF='MMMM yyyy'");
	ElsIf Find(SentForm.FormName, "ListForm") > 0 Then
		SentForm.FilterRegistrationPeriod 			= BegOfMonth(SentForm.FilterRegistrationPeriod);
		SentForm.RegistrationPeriodPresentation 	= Format(SentForm.FilterRegistrationPeriod, "DF='MMMM yyyy'");
	Else
		SentForm.Object.RegistrationPeriod 		= BegOfMonth(SentForm.Object.RegistrationPeriod);
		SentForm.RegistrationPeriodPresentation 	= Format(SentForm.Object.RegistrationPeriod, "DF='MMMM yyyy'");
	EndIf;
	
EndProcedure

// Procedure executes date increment by
// regulatory buttons Used in log and salary documents and wages Expense CA from
// petty cash, reports Payroll sheets Step equals to month
//
// Parameters:
// SentForm 	- form data of
// which is corrected Direction 		- increment value can be positive or negative
Procedure OnRegistrationPeriodRegulation(SentForm, Direction) Export
	
	If Find(SentForm.FormName, "DocumentJournal") > 0 
		OR Find(SentForm.FormName, "ReportForm") Then
		
		SentForm.RegistrationPeriod = ?(ValueIsFilled(SentForm.RegistrationPeriod), 
							AddMonth(SentForm.RegistrationPeriod, Direction),
							AddMonth(BegOfMonth(CommonClient.SessionDate()), Direction));
		
	ElsIf Find(SentForm.FormName, "ListForm") > 0 Then
		
		SentForm.FilterRegistrationPeriod = ?(ValueIsFilled(SentForm.FilterRegistrationPeriod), 
							AddMonth(SentForm.FilterRegistrationPeriod, Direction),
							AddMonth(BegOfMonth(CommonClient.SessionDate()), Direction));
		
	Else
		
		SentForm.Object.RegistrationPeriod = ?(ValueIsFilled(SentForm.Object.RegistrationPeriod), 
							AddMonth(SentForm.Object.RegistrationPeriod, Direction),
							AddMonth(BegOfMonth(CommonClient.SessionDate()), Direction));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PricingSubsystemProceduresAndFunctions

// Procedure calculates the amount of the tabular section while filling by "Prices and currency".
//
Procedure CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow, DocumentHasVAT = True)
	
	If TabularSectionRow.Property("Quantity") AND TabularSectionRow.Property("Price") Then
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf;
	
	If TabularSectionRow.Property("StandardHours") Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * TabularSectionRow.StandardHours;
	EndIf;
	
	If TabularSectionRow.Property("DiscountMarkupPercent") Then
		If TabularSectionRow.DiscountMarkupPercent = 100 Then
			TabularSectionRow.Amount = 0;
		ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
			TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		EndIf;
	EndIf;
	
	If TabularSectionRow.Property("DiscountPercent") Then
		TabularSectionRow.DiscountAmount = TabularSectionRow.DiscountPercent * TabularSectionRow.Amount / 100;
		TabularSectionRow.Amount = TabularSectionRow.Amount - TabularSectionRow.DiscountAmount;
	EndIf;

	VATRate = ?(TabularSectionRow.Property("VATRate"), DriveReUse.GetVATRateValue(TabularSectionRow.VATRate), 0);
	
	If DocumentForm.Object.Property("AmountIncludesVAT") Then
		TabularSectionRow.VATAmount = ?(
			DocumentForm.Object.AmountIncludesVAT, 
			TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
			TabularSectionRow.Amount * VATRate / 100
		);
		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentForm.Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	ElsIf TabularSectionRow.Property("VATRate") And TabularSectionRow.Property("Total") Then
		TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
		TabularSectionRow.Total = TabularSectionRow.Amount + TabularSectionRow.VATAmount;
	EndIf;	
	
	// AutomaticDiscounts
	If TabularSectionRow.Property("AutomaticDiscountsPercent") Then
		TabularSectionRow.AutomaticDiscountsPercent = 0;
		TabularSectionRow.AutomaticDiscountAmount = 0;
	EndIf;
	If TabularSectionRow.Property("TotalDiscountAmountIsMoreThanAmount") Then
		TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Recalculate prices by the AmountIncludesVAT check box of the tabular section after changes in form "Prices and currency".
//
// Parameters:
//  PreviousCurrency - CatalogRef.Currencies,
//                 contains reference to the previous currency.
//
Procedure RecalculateTabularSectionAmountByFlagAmountIncludesVAT(DocumentForm, TabularSectionName, PricesPrecision = 2) Export
																	   
	For Each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
		If TabularSectionRow.Property("Price") Then
			
			If DocumentForm.Object.AmountIncludesVAT Then
				TabularSectionRow.Price = Round((TabularSectionRow.Price * (100 + VATRate)) / 100, PricesPrecision);
			Else
				TabularSectionRow.Price = Round((TabularSectionRow.Price * 100) / (100 + VATRate), PricesPrecision);
			EndIf;
			
			CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
		EndIf;
		        
	EndDo;

EndProcedure

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesByPriceKind(DocumentForm, TabularSectionName, RecalculateDiscounts = False) Export
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;
	
	DocumentHasVAT = DocumentForm.Object.Property("AmountIncludesVAT");

	DataStructure.Insert("Date",				DocumentForm.Object.Date);
	DataStructure.Insert("Company",				DocumentForm.ParentCompany);
	DataStructure.Insert("PriceKind",			DocumentForm.Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",	DocumentForm.Object.DocumentCurrency);
	If DocumentHasVAT Then
		DataStructure.Insert("AmountIncludesVAT",	DocumentForm.Object.AmountIncludesVAT);
	EndIf;
	
	If RecalculateDiscounts Then
		DataStructure.Insert("DiscountMarkupKind", DocumentForm.Object.DiscountMarkupKind);
		DataStructure.Insert("DiscountMarkupPercent", 0);
		If DriveServer.DocumentAttributeExistsOnLink("DiscountPercentByDiscountCard", DocumentForm.Object.Ref) Then
			DataStructure.Insert("DiscountPercentByDiscountCard", DocumentForm.Object.DiscountPercentByDiscountCard);		
		EndIf;
	EndIf;
	
	For Each TSRow In DocumentForm.Object[TabularSectionName] Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.Products) Then
			Continue;	
		EndIf; 
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products",		TSRow.Products);
		TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		If DocumentHasVAT Then
			TabularSectionRow.Insert("VATRate",			TSRow.VATRate);
		EndIf;
		// Bundles
		If TSRow.Property("BundleProduct") Then
			TabularSectionRow.Insert("BundleProduct",			TSRow.BundleProduct);
			TabularSectionRow.Insert("BundleCharacteristic",	TSRow.BundleCharacteristic);
			TabularSectionRow.Insert("CostShare",				TSRow.CostShare);
			TabularSectionRow.Insert("Quantity",				TSRow.Quantity);
			If DocumentForm.Object.Property("AddedBundles") Then
				FilterStructure = New Structure;
				FilterStructure.Insert("BundleProduct", TSRow.BundleProduct);
				FilterStructure.Insert("BundleCharacteristic", TSRow.BundleCharacteristic);
				If TSRow.Property("Variant") Then
					FilterStructure.Insert("Variant", TSRow.Variant);
				EndIf;
				AddedRows = DocumentForm.Object.AddedBundles.FindRows(FilterStructure);
				If AddedRows.Count() = 0 Then
					FilterStructure.Insert("BundesQuantity", 1);
				Else
					FilterStructure.Insert("BundesQuantity", AddedRows[0].Quantity);
				EndIf;
			Else
				TabularSectionRow.Insert("BundesQuantity", 1);
			EndIf;
			If TSRow.Property("Variant") Then
				TabularSectionRow.Insert("Variant", TSRow.Variant);
			Else
				TabularSectionRow.Insert("Variant", 0);
			EndIf;
		EndIf;
		// End Bundles
		TabularSectionRow.Insert("Price",				0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
		
	DriveServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
		
	For Each TSRow In DocumentTabularSection Do
	
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",		TSRow.Products);
		SearchStructure.Insert("Characteristic",		TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		If DocumentHasVAT Then
			SearchStructure.Insert("VATRate",			TSRow.VATRate);
		EndIf;

		SearchResult = DocumentForm.Object[TabularSectionName].FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			CalculateTabularSectionRowSUM(DocumentForm, ResultRow, DocumentHasVAT);
			
		EndDo;
		
	EndDo;
	
	If RecalculateDiscounts Then
		For Each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
			TabularSectionRow.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent;
			CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
		EndDo;
	EndIf;
	
EndProcedure

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesBySupplierPriceTypes(DocumentForm, TabularSectionName, RecalculateDiscounts = False) Export
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				DocumentForm.Object.Date);
	DataStructure.Insert("Company",				DocumentForm.Object.Company);
	DataStructure.Insert("Counterparty",		DocumentForm.Object.Counterparty);
	DataStructure.Insert("SupplierPriceTypes",	DocumentForm.Object.SupplierPriceTypes);
	DataStructure.Insert("DocumentCurrency",	DocumentForm.Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	DocumentForm.Object.AmountIncludesVAT);
	
	If RecalculateDiscounts Then
		DataStructure.Insert("DiscountType", DocumentForm.Object.DiscountType);
		If ValueIsFilled(DataStructure.DiscountType) Then
			DataStructure.Insert("DiscountPercent",
				DriveServerCall.ObjectAttributeValue(DataStructure.DiscountType, "Percent"));
		Else
			DataStructure.Insert("DiscountPercent", 0);
		EndIf;
	EndIf;
	
	If DriveServerCall.GetFunctionalOptionValue("UseCounterpartiesPricesTracking") Then
		
		For Each TSRow In DocumentForm.Object[TabularSectionName] Do
			
			TSRow.Price = 0;
			
			If Not ValueIsFilled(TSRow.Products) Then
				Continue;	
			EndIf; 
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("Products",		TSRow.Products);
			TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
			TabularSectionRow.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
			TabularSectionRow.Insert("VATRate",			TSRow.VATRate);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;
		
		DriveServer.GetPricesTabularSectionBySupplierPriceTypes(DataStructure, DocumentTabularSection);
		
		For Each TSRow In DocumentTabularSection Do
			
			SearchStructure = New Structure;
			SearchStructure.Insert("Products",		TSRow.Products);
			SearchStructure.Insert("Characteristic",		TSRow.Characteristic);
			SearchStructure.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
			SearchStructure.Insert("VATRate",			TSRow.VATRate);
			
			SearchResult = DocumentForm.Object[TabularSectionName].FindRows(SearchStructure);
			
			For Each ResultRow In SearchResult Do
				
				ResultRow.Price = TSRow.Price;
				CalculateTabularSectionRowSUM(DocumentForm, ResultRow);
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
	If RecalculateDiscounts Then
		For Each TSRow In DocumentForm.Object[TabularSectionName] Do
			TSRow.DiscountPercent = DataStructure.DiscountPercent;
			CalculateTabularSectionRowSUM(DocumentForm, TSRow);
		EndDo;
	EndIf;
	
EndProcedure

// Recalculate price by document tabular section currency after changes in the "Prices and currency" form.
//
// Parameters:
//  PreviousCurrency - CatalogRef.Currencies,
//                 contains reference to the previous currency.
//
Procedure RecalculateTabularSectionPricesByCurrency(DocumentForm, DocCurStructure, TabularSectionName, PricesPrecision = 2) Export
	
	If DocCurStructure.Property("InitRate")
		And DocCurStructure.Property("RepetitionBeg")
		And DocCurStructure.Property("Rate")
		And DocCurStructure.Property("Repetition") Then
		RatesStructure = DocCurStructure;
	Else
		RatesStructure = DriveServer.GetExchangeRate(DocumentForm.Object.Company,
			DocCurStructure.PrevDocumentCurrency,
			DocCurStructure.DocumentCurrency,
			DocumentForm.Object.Date);
	EndIf;
	
	ExchangeRateMethod = DriveServer.GetExchangeMethod(DocumentForm.Object.Company);
	
	For Each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
		
		// Price.
		If TabularSectionRow.Property("Price") Then
			
			TabularSectionRow.Price = DriveServer.RecalculateFromCurrencyToCurrency(TabularSectionRow.Price,
																	ExchangeRateMethod,
																	RatesStructure.InitRate,
																	RatesStructure.Rate,
																	RatesStructure.RepetitionBeg,
																	RatesStructure.Repetition,
																	PricesPrecision);
				
			CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
			
		// Amount.
		ElsIf TabularSectionRow.Property("Amount") Then
			
			TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToCurrency(TabularSectionRow.Amount,
																	ExchangeRateMethod,
																	RatesStructure.InitRate,
																	RatesStructure.Rate,
																	RatesStructure.RepetitionBeg,
																	RatesStructure.Repetition,
																	PricesPrecision);
				
			If TabularSectionRow.Property("DiscountMarkupPercent") Then
				
				// Discounts.
				If TabularSectionRow.DiscountMarkupPercent = 100 Then
					TabularSectionRow.Amount = 0;
				ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
					TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
				EndIf;
				
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
			TabularSectionRow.VATAmount = ?(DocumentForm.Object.AmountIncludesVAT,
				TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
				TabularSectionRow.Amount * VATRate / 100);
			
			If TabularSectionRow.Property("Total") Then
				TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentForm.Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			EndIf;
			
		// Offset amount.
		ElsIf TabularSectionRow.Property("OffsetAmount") Then
			
			TabularSectionRow.OffsetAmount = DriveServer.RecalculateFromCurrencyToCurrency(TabularSectionRow.OffsetAmount, 
																	ExchangeRateMethod,
																	RatesStructure.InitRate,
																	RatesStructure.Rate,
																	RatesStructure.RepetitionBeg,
																	RatesStructure.Repetition,
																	PricesPrecision);
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
			TabularSectionRow.VATAmount = ?(DocumentForm.Object.AmountIncludesVAT,
				TabularSectionRow.OffsetAmount - (TabularSectionRow.OffsetAmount) / ((VATRate + 100) / 100),
				TabularSectionRow.OffsetAmount * VATRate / 100);
			
		// Cost value
		ElsIf TabularSectionRow.Property("CostValue") Then
			
			TabularSectionRow.CostValue = DriveServer.RecalculateFromCurrencyToCurrency(TabularSectionRow.CostValue,
																	ExchangeRateMethod,
																	RatesStructure.InitRate,
																	RatesStructure.Rate,
																	RatesStructure.RepetitionBeg,
																	RatesStructure.Repetition,
																	PricesPrecision);
				
			If TabularSectionRow.Property("Total") Then
				TabularSectionRow.Total = TabularSectionRow.Quantity * TabularSectionRow.CostValue;
			EndIf;
			
		EndIf;
			
	EndDo;
	
EndProcedure

#Region DiscountCards

// Recalculate document tabular section amount after reading discount card.
Procedure RefillDiscountsTablePartAfterDiscountCardRead(DocumentForm, TabularSectionName) Export
	
	Discount = DriveServer.GetDiscountPercentByDiscountMarkupKind(DocumentForm.Object.DiscountMarkupKind) + DocumentForm.Object.DiscountPercentByDiscountCard;
	
	For Each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
		
		TabularSectionRow.DiscountMarkupPercent = Discount;
		CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region ProceduresAndFunctionsOfAdditionalAttributesSubsystem

// Procedure expands values tree on form.
//
Procedure ExpandPropertiesValuesTree(FormItem, Tree) Export
	
	For Each Item In Tree.GetItems() Do
		ID = Item.GetID();
		FormItem.Expand(ID, True);
	EndDo;
	
EndProcedure

// Procedure handler of the BeforeDeletion event.
//
Procedure PropertyValueTreeBeforeDelete(Item, Cancel, Modified) Export
	
	Cancel = True;
	Item.CurrentData.Value = Item.CurrentData.PropertyValueType.AdjustValue(Undefined);
	Modified = True;
	
EndProcedure

// Procedure handler of the OnStartEdit event.
//
Procedure PropertyValueTreeOnStartEdit(Item) Export
	
	Item.ChildItems.Value.TypeRestriction = Item.CurrentData.PropertyValueType;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfWorkWithDynamicLists

// Deletes dynamic list filter item
//
// Parameters:
// List  - processed dynamic
// list, FieldName - layout field name filter by which should be deleted
//
Procedure DeleteListFilterItem(List, FieldName) Export
	
	CompositionField = New DataCompositionField(FieldName);
	Counter = 1;
	While Counter <= List.Filter.Items.Count() Do
		FilterItem = List.Filter.Items[Counter - 1];
		If TypeOf(FilterItem) = Type("DataCompositionFilterItem")
			AND FilterItem.LeftValue = CompositionField Then
			List.Filter.Items.Delete(FilterItem);
		Else
			Counter = Counter + 1;
		EndIf;	
	EndDo; 
	
EndProcedure

// Sets dynamic list filter item
//
// Parameters:
// List			- processed dynamic
// list, FieldName			- layout field name filter on which
// should be set, ComparisonKind		- filter comparison kind, by default - Equal,
// RightValue 	- filter value
//
Procedure SetListFilterItem(List, FieldName, RightValue, ComparisonType = Undefined) Export
	
	FilterItem = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue    = New DataCompositionField(FieldName);
	FilterItem.ComparisonType     = ?(ComparisonType = Undefined, DataCompositionComparisonType.Equal, ComparisonType);
	FilterItem.Use    = True;
	FilterItem.RightValue   = RightValue;
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
EndProcedure

// Changes dynamic list filter item
//
// Parameters:
// List         - processed dynamic
// list, FieldName        - layout field name filter on which
// should be set, ComparisonKind   - filter comparison kind, by default - Equal,
// RightValue - filter
// value, Set     - shows that it is required to set filter
//
Procedure ChangeListFilterElement(List, FieldName, RightValue = Undefined, Set = False, ComparisonType = Undefined, FilterByPeriod = False) Export
	
	DeleteListFilterItem(List, FieldName);
	
	If Set Then
		If FilterByPeriod Then
			SetListFilterItem(List, FieldName, RightValue.StartDate, DataCompositionComparisonType.GreaterOrEqual);
			SetListFilterItem(List, FieldName, RightValue.EndDate, DataCompositionComparisonType.LessOrEqual);		
		Else
		    SetListFilterItem(List, FieldName, RightValue, ComparisonType);	
		EndIf;		
	EndIf;
	
EndProcedure

// Function reads values of dynamic list filter items
//
Function ReadValuesOfFilterDynamicList(List) Export
	
	FillingData = New Structure;
	
	If TypeOf(List) = Type("DynamicList") Then
		
		For Each FilterDynamicListItem In List.SettingsComposer.Settings.Filter.Items Do
			
			FilterName = String(FilterDynamicListItem.LeftValue);
			FilterValue = FilterDynamicListItem.RightValue;
			
			If Find(FilterName, ".") > 0 OR Not FilterDynamicListItem.Use Then
				
				Continue;
				
			EndIf;
			
			FillingData.Insert(FilterName, FilterValue);
			
		EndDo;
		
	EndIf;
	
	Return FillingData;
	
EndFunction

#EndRegion

#Region CalculationsManagementProceduresAndFunctions

// Procedure opens a form of totals calculations self management
//
Procedure TotalsControl() Export
	
EndProcedure

#EndRegion

#Region PrintingManagementProceduresAndFunctions

// Function generates title for the general form "Printing".
// CommandParameter - printing command parameter.
//
Function GetTitleOfPrintedForms(CommandParameter) Export
	
	If TypeOf(CommandParameter) = Type("Array") 
		AND CommandParameter.Count() = 1 Then 
		
		Return New Structure("FormTitle", CommandParameter[0]);
		
	EndIf;

	Return Undefined;
	
EndFunction

// Processor procedure the "LabelPrinting" or "PriceTagCommand" command from documents 
// - Stock summary
// - Supplier invoice
//
Function PrintLabelsAndPriceTagsFromDocuments(CommandParameter) Export
	
	If CommandParameter.Count() > 0 Then
		
		ObjectArrayPrint = CommandParameter.PrintObjects;
		IsPriceTags = Find(CommandParameter.ID, "TagsPrinting") > 0;
		AddressInStorage = DriveServer.PreparePriceTagsAndLabelsPrintingFromDocumentsDataStructure(ObjectArrayPrint, IsPriceTags);
		ParameterStructure = New Structure("AddressInStorage", AddressInStorage);
		OpenForm("DataProcessor.PrintLabelsAndTags.Form.Form", ParameterStructure, , New UUID);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Function GenerateContractForms(CommandParameter) Export
	
	For Each PrintObject In CommandParameter.PrintObjects Do
		
		Parameters = New Structure;
		Parameters.Insert("Key", DriveServer.GetContractDocument(PrintObject));
		Parameters.Insert("Document", PrintObject);
		OpenForm("Catalog.CounterpartyContracts.ObjectForm", Parameters);
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Function PrintCounterpartyContract(CommandParameter) Export
		
	If CommandParameter.Form.FormName = "Catalog.CounterpartyContracts.Form.ItemForm" Then 
		PrintingSource = CommandParameter.Form;
		PrintingSource.PrintCounterpartyContract();
	Else
		
		CurrentData = CommandParameter.Form.Items.List.CurrentData;
		If CurrentData = Undefined Then
			Return Undefined;
		EndIf;
		
		FormParameters	= New Structure;
		FormParameters.Insert("Key", CurrentData.Ref);
		FormParameters.Insert("PrintCounterpartyContract", True);
		
		OpenForm("Catalog.CounterpartyContracts.ObjectForm", FormParameters);
		
	EndIf;
	
EndFunction

Function PrintCounterpartyContractQuestion(Result, AdditionalParameters) Export
	
	PrintingSource = AdditionalParameters.PrintingSource;
	
	If Result = DialogReturnCode.Yes Then
		PrintCounterpartyContractEnd(PrintingSource);
	EndIf;
	
EndFunction

Function PrintCounterpartyContractEnd(PrintingSource) Export
	
	document = PrintingSource.Items.ContractHTMLDocument.Document;
	If document.execCommand("Print") = False Then 
		document.defaultView.print();
	EndIf;
	
EndFunction

#EndRegion

#Region PredefinedProceduresAndFunctionsOfEmailSending

// Interface client procedure that supports call of new email editing form.
// While sending email via the standard common form EmailMessage messages are not saved in the infobase.
//
// For the parameters, see description of the WorkWithPostalMailClient.CreateNewEmail function.
//
Procedure OpenEmailMessageSendForm(Sender, Recipient, Subject, Text, FileList, BasisDocuments, DeleteFilesAfterSend, OnCloseNotifyDescription) Export
	
	EmailParameters = New Structure;
	
	EmailParameters.Insert("FillingValues", New Structure("EventType", PredefinedValue("Enum.EventTypes.Email")));
	
	EmailParameters.Insert("UserAccount", Sender);
	EmailParameters.Insert("Whom", Recipient);
	EmailParameters.Insert("Subject", Subject);
	EmailParameters.Insert("Body", Text);
	EmailParameters.Insert("Attachments", FileList);
	EmailParameters.Insert("BasisDocuments", BasisDocuments);
	EmailParameters.Insert("DeleteFilesAfterSend", DeleteFilesAfterSend);
	
	OpenForm("Document.Event.Form.EmailForm", EmailParameters, , , , , OnCloseNotifyDescription);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// General module Common does not support "Server call" any more.
// Corrections and support of a new behavior
//
// Replaces
// call Common.ObjectAttributeValue from the Add() procedure of the Price-list processor form
//
Function ReadAttributeValue_Owner(ObjectOrRef) Export
	
	Return DriveServer.ReadAttributeValue_Owner(ObjectOrRef);
	
EndFunction

Function ReadAttributeValue_IsFolder(ObjectOrRef) Export
	
	Return DriveServer.ReadAttributeValue_IsFolder(ObjectOrRef);
	
EndFunction

#EndRegion

#Region GenerateCommands

Procedure GoodsIssueGenerationBasedOnSalesOrder(SalesOrdersListItem) Export

	If SalesOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = SalesOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.GoodsIssue.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckOrdersAndInvoicesKeyAttributesForGoodsIssue(OrdersArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках заказов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';tr = 'Siparişler belge başlıklarında farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Vuoi dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsIssue",
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateGoodsIssue(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure GoodsIssueGenerationBasedOnSalesInvoice(SalesInvoicesListItem) Export

	If SalesInvoicesListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	InvoicesArray = SalesInvoicesListItem.SelectedRows;
	
	If InvoicesArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", InvoicesArray[0]);
		OpenForm("Document.GoodsIssue.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckOrdersAndInvoicesKeyAttributesForGoodsIssue(InvoicesArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The invoices have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках инвойсов различаются %1. Разделить их на несколько документов?';pl = 'Faktury mają inne znaczenie %1 w nagłówkach dokumentów. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Las facturas tienen diferentes %1 en los títulos del documento. ¿Quiere dividirlas para varios documentos?';es_CO = 'Las facturas tienen diferentes %1 en los títulos del documento. ¿Quiere dividirlas para varios documentos?';tr = 'Faturaların belge başlıkları farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Le fatture hanno differente %1 nelle intestazioni documento. Volete separarle in diversi documenti?';de = 'Die Rechnungen haben unterschiedliche %1 in den Dokumentkopfzeilen. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsIssueBasedOnSalesInvoice",
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("ArrayOfSalesInvoices", InvoicesArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure GoodsReceiptGenerationBasedOnSalesInvoice(SalesInvoicesListItem) Export

	If SalesInvoicesListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	InvoicesArray = SalesInvoicesListItem.SelectedRows;
	
	If InvoicesArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", InvoicesArray[0]);
		OpenForm("Document.GoodsReceipt.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckSalesInvoicesKeyAttributes(InvoicesArray);
		If DataStructure.CreateMultipleDocuments Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The invoices have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках инвойсов различаются %1. Разделить их на несколько документов?';pl = 'Faktury mają inne znaczenie %1 w nagłówkach dokumentów. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Las facturas tienen diferentes %1 en los títulos del documento. ¿Quiere dividirlas para varios documentos?';es_CO = 'Las facturas tienen diferentes %1 en los títulos del documento. ¿Quiere dividirlas para varios documentos?';tr = 'Faturaların belge başlıkları farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Le fatture hanno differente %1 nelle intestazioni documento. Volete separarle in diversi documenti?';de = 'Die Rechnungen haben unterschiedliche %1 in den Dokumentkopfzeilen. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsReceiptBasedOnSalesInvoice",
					ThisObject,
					New Structure("SalesInvoiceGroups", DataStructure.SalesInvoiceGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("ArrayOfSalesInvoices", InvoicesArray);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure GoodsIssueGenerationBasedOnSupplierInvoice(SupplierInvoicesListItem, IsDropShipping = False) Export

	If TypeOf(SupplierInvoicesListItem) = Type("Array") Then
		SupplierInvoicesArray = SupplierInvoicesListItem;
	Else
		
		If SupplierInvoicesListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		SupplierInvoicesArray = SupplierInvoicesListItem.SelectedRows;
		
	EndIf;
	
	If IsDropShipping Then
		OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.DropShipping");
	Else 
		OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.SaleToCustomer");
	EndIf;
	
	BasisStructure = New Structure;
	BasisStructure.Insert("ArrayOfSupplierInvoices", SupplierInvoicesArray);
	BasisStructure.Insert("OperationType", OperationType);
	OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
		
EndProcedure

Procedure GoodsIssueReturnGenerationBasedOnSupplierInvoice(SupplierInvoicesListItem) Export

	If TypeOf(SupplierInvoicesListItem) = Type("Array") Then
		InvoicesArray = SupplierInvoicesListItem;
	Else
		
		If SupplierInvoicesListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		InvoicesArray = SupplierInvoicesListItem.SelectedRows;
		
	EndIf;
	
	DataStructure = DriveServer.CheckSupplierInvoicesKeyAttributes(InvoicesArray);
	
	If InvoicesArray.Count() > 1
		And DataStructure.CreateMultipleDocuments Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'The invoices have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках инвойсов различаются %1. Разделить их на несколько документов?';pl = 'Faktury mają inne znaczenie %1 w nagłówkach dokumentów. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Las facturas tienen diferentes %1 en los títulos del documento. ¿Quiere dividirlas para varios documentos?';es_CO = 'Las facturas tienen diferentes %1 en los títulos del documento. ¿Quiere dividirlas para varios documentos?';tr = 'Faturaların belge başlıkları farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Le fatture hanno differente %1 nelle intestazioni documento. Volete separarle in diversi documenti?';de = 'Die Rechnungen haben unterschiedliche %1 in den Dokumentkopfzeilen. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
		DataStructure.DataPresentation);
		
		ShowQueryBox(
		New NotifyDescription("CreateGoodsIssueBasedOnSupplierInvoice",
		ThisObject,
		New Structure("SupplierInvoiceGroups", DataStructure.SupplierInvoiceGroups)),
		MessageText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.PurchaseReturn");
		BasisStructure = New Structure;
		BasisStructure.Insert("ArrayOfSupplierInvoices", InvoicesArray);
		BasisStructure.Insert("OperationType", OperationType);
		OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;
	
EndProcedure

Procedure GoodsIssueGenerationBasedOnDebitNote(DebitNotesListItem) Export

	If DebitNotesListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	DebitNotesArray = DebitNotesListItem.SelectedRows;
	
	If DebitNotesArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", DebitNotesArray[0]);
		OpenForm("Document.GoodsIssue.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckDebitNotesKeyAttributes(DebitNotesArray);
		If DataStructure.CreateMultipleDocuments Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The documetns have different %1 in document headers. Do you want to split them into several documents?'; ru = 'У заголовках документов различаются %1. Разделить их на несколько документов?';pl = 'Dokumenty mają inne znaczenie %1 w nagłówkach dokumentów. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los documentos tienen diferentes %1en los encabezados de los documentos. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los documentos tienen diferentes %1en los encabezados de los documentos. ¿Quiere dividirlos para varios documentos?';tr = 'Belgelerin başlıkları farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'I documenti hanno differente %1 nell''intestazione del documento. Volete separarli in più documenti?';de = 'Die Dokumente haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsIssueBasedOnDebitNote",
					ThisObject,
					New Structure("DocumentGroups", DataStructure.DocumentGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("ArrayOfDebitNotes", DebitNotesArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateGoodsIssueBasedOnSalesInvoice(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesInvoices", OrdersArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure GoodsReceiptGenerationBasedOnPurchaseOrder(PurchaseOrdersListItem) Export

	If PurchaseOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = PurchaseOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.GoodsReceipt.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckPurchaseOrdersSupplierInvoicesKeyAttributes(OrdersArray, True);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках заказов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';tr = 'Siparişler belge başlıklarında farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Vuoi dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsReceipt",
					ThisObject,
					New Structure("OrdersGroups, ArrayName", DataStructure.OrdersGroups, "OrdersArray")),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("OrdersArray", OrdersArray);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure GoodsReceiptGenerationBasedOnSupplierInvoice(SupplierInvoicesListItem) Export

	If SupplierInvoicesListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	InvoicesArray = SupplierInvoicesListItem.SelectedRows;
	
	If InvoicesArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", InvoicesArray[0]);
		OpenForm("Document.GoodsReceipt.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckPurchaseOrdersSupplierInvoicesKeyAttributes(InvoicesArray, True);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The invoices have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках инвойсов различаются %1. Разделить их на несколько документов?';pl = 'Faktury mają inne znaczenie %1 w nagłówkach dokumentów. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Las facturas tienen diferentes %1 en los títulos del documento. ¿Quiere dividirlas para varios documentos?';es_CO = 'Las facturas tienen diferentes %1 en los títulos del documento. ¿Quiere dividirlas para varios documentos?';tr = 'Faturaların belge başlıkları farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Le fatture hanno differente %1 nelle intestazioni documento. Volete separarle in diversi documenti?';de = 'Die Rechnungen haben unterschiedliche %1 in den Dokumentkopfzeilen. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsReceipt",
					ThisObject,
					New Structure("OrdersGroups, ArrayName", DataStructure.OrdersGroups, "InvoicesArray")),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("InvoicesArray", InvoicesArray);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure GoodsReceiptGenerationBasedOnRMARequest(RMARequestsListItem) Export

	If RMARequestsListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	RMARequestArray = RMARequestsListItem.SelectedRows;
	
	If RMARequestArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", RMARequestArray[0]);
		OpenForm("Document.GoodsReceipt.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckRMARequestKeyAttributes(RMARequestArray);
		If DataStructure.CreateMultipleGoodsReceipt Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The RMA requests have different %1. Do you want to split them into several documents?'; ru = 'В сервисных запросах различаются %1. Разделить их на несколько документов?';pl = 'Żądania RMA różnią się %1. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Las solicitudes RMA tienen diferentes %1 en el documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Las solicitudes RMA tienen diferentes %1 en el documento. ¿Quiere dividirlos para varios documentos?';tr = 'RMA taleplerinde %1 farklı. Bunları birkaç belgeye ayırmak ister misiniz?';it = 'Le richieste RMA hanno differente %1. Volete separarle in diversi documenti?';de = 'Die RMA-Anfragen haben unterschiedliche %1. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsReceiptBasedOnRMARequest",
					ThisObject,
					New Structure("RequestGroups", DataStructure.RequestGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("RMARequestArray", RMARequestArray);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateGoodsReceipt(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert(AdditionalParameters.ArrayName, OrdersArray);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CreateGoodsReceiptBasedOnRMARequest(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		For Each RMARequestArray In AdditionalParameters.RequestGroups Do
			
			FillStructure = New Structure;
			FillStructure.Insert("RMARequestArray", RMARequestArray);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", FillStructure), , True);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure SalesInvoiceGenerationBasedOnGoodsIssue(GoodsIssueListItem) Export

	If TypeOf(GoodsIssueListItem) = Type("Array") Then
		GoodsIssueArray = GoodsIssueListItem;
	Else
		
		If GoodsIssueListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		GoodsIssueArray = GoodsIssueListItem.SelectedRows;
	EndIf;
	
	DataStructure = DriveServer.CheckGoodsIssueKeyAttributes(GoodsIssueArray);
	If DataStructure.CreateMultipleInvoices Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The goods issues have different %1 in document. Do you want to split them into several documents?'; ru = 'В отпусках товаров различаются %1. Разделить их на несколько документов?';pl = 'Wydania zewnętrzne różnią się %1 w dokumencie. Chcesz podzielić je na kilka dokumentów?';es_ES = 'Las salidas de mercancías tienen diferentes %1 en el documento. ¿Quiere dividirlas para varios documentos?';es_CO = 'Las emisiones de mercancías tienen diferentes %1 en el documento. ¿Quiere dividirlas para varios documentos?';tr = 'Ambar çıkışı belgede farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Le spedizioni merci hanno diversi %1 nel documento. Vuoi dividerle in diversi documenti?';de = 'Die Warenausgänge haben unterschiedliche %1 in dem Dokument. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
			DataStructure.DataPresentation);
		
		ShowQueryBox(
			New NotifyDescription("CreateSalesInvoicesBasedOnGoodsIssue", 
				ThisObject,
				New Structure("GoodsIssueGroups", DataStructure.GoodsIssueGroups)),
			MessageText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		BasisStructure = New Structure;
		BasisStructure.Insert("ArrayOfGoodsIssues", GoodsIssueArray);
		OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;

EndProcedure

Procedure CreateSalesInvoicesBasedOnGoodsIssue(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each GoodsIssueArray In AdditionalParameters.GoodsIssueGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfGoodsIssues", GoodsIssueArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CreateSalesInvoicesBasedOnSupplierInvoice(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each InvoiceArray In AdditionalParameters.InvoicesGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfInvoices", InvoiceArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure SalesInvoiceGenerationBasedOnSalesOrder(SalesOrdersListItem) Export

	If SalesOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = SalesOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.SalesInvoice.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckOrdersKeyAttributes(OrdersArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках заказов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';tr = 'Siparişler belge başlıklarında farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Vuoi dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateSalesInvoices", 
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure();
			BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure SalesInvoiceGenerationBasedOnWorkOrder(WorkOrdersListItem) Export

	If WorkOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = WorkOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.SalesInvoice.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckWorkOrdersKeyAttributes(OrdersArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках заказов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';tr = 'Siparişler belge başlıklarında farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Vuoi dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateSalesInvoicesOnWorkOrder", 
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure();
			BasisStructure.Insert("ArrayOfWorkOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure SalesInvoiceGenerationBasedOnSupplierInvoice(SupplierInvoicesListItem) Export

	If TypeOf(SupplierInvoicesListItem) = Type("Array") Then
		InvoicesArray = SupplierInvoicesListItem;
	Else
		
		If SupplierInvoicesListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		InvoicesArray = SupplierInvoicesListItem.SelectedRows;
		
	EndIf;
	
	BasisStructure = New Structure;
	BasisStructure.Insert("ArrayOfInvoices", InvoicesArray);
	OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
		

EndProcedure

Procedure CreateSalesInvoices(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CreateSalesInvoicesOnWorkOrder(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfWorkOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure SupplierInvoiceGenerationBasedOnPurchaseOrder(PurchaseOrdersListItem) Export

	If PurchaseOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = PurchaseOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.SupplierInvoice.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckPurchaseOrdersSupplierInvoicesKeyAttributes(OrdersArray);
		
		If DataStructure.NumberOfOperations > 1 Then
			
			WarningText = NStr("en = 'Cannot generate a single Supplier invoice for multiple Purchase orders 
							|with different Operation types. 
							|Select Purchase orders with the same Operation. Then try again.'; 
							|ru = 'Не удалось создать инвойс поставщика для нескольких заказов поставщикам 
							|с разными типами операций. 
							|Выберите заказы поставщикам с одинаковой операцией. Затем повторите попытку.';
							|pl = 'Nie można wygenerować oddzielnej faktury zakupu dla kilku Zamówień zakupu 
							|z różnymi Typami operacji. 
							|Wybierz Zamówienia zakupu z taką samą Operacją. Następnie spróbuj ponownie.';
							|es_ES = 'No se puede generar una única factura de proveedor para varias órdenes de compra
							|con diferentes tipos de Operación.
							|Seleccione las órdenes de compra con la misma Operación. A continuación, inténtelo de nuevo.';
							|es_CO = 'No se puede generar una única factura de proveedor para varias órdenes de compra
							|con diferentes tipos de Operación.
							|Seleccione las órdenes de compra con la misma Operación. A continuación, inténtelo de nuevo.';
							|tr = 'Farklı işlem türlerine sahip birden fazla Satın alma siparişi için tek bir 
							|Satın alma faturası oluşturulamaz. 
							|Aynı İşleme sahip Satın alma siparişleri seçip tekrar deneyin.';
							|it = 'Impossibile generare una singola Fattura del fornitore per Ordini di acquisto multipli
							|con diverso Tipo di operazione. 
							|Selezionare gli Ordini di acquisto con la stessa Operazione, poi riprovare.';
							|de = 'Fehler beim Generieren einer einzigen Lieferantenrechnung für mehrere Bestellungen an Lieferanten 
							| mit unterschiedlichen Operationstypen. 
							| Wählen Sie die Bestellungen an Lieferanten mit derselben Operation aus. Dann versuchen Sie erneut.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках заказов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';tr = 'Siparişler belge başlıklarında farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Vuoi dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateSuppliersInvoices", 
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure();
			BasisStructure.Insert("ArrayOfPurchaseOrders", OrdersArray);
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateSuppliersInvoices(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfPurchaseOrders", OrdersArray);
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure SupplierInvoiceGenerationBasedOnGoodsReceipt(GoodsReceiptListItem, IsDropShipping = False) Export

	If TypeOf(GoodsReceiptListItem) = Type("Array") Then
		GoodsReceiptArray = GoodsReceiptListItem;
	Else
		
		If GoodsReceiptListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		GoodsReceiptArray = GoodsReceiptListItem.SelectedRows;
	EndIf;
	
	DataStructure = DriveServer.CheckGoodsReceiptKeyAttributes(GoodsReceiptArray);
	If DataStructure.CreateMultipleInvoices Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The goods receipts have different %1 in document. Do you want to split them into several documents?'; ru = 'В поступлениях товаров различаются %1. Разделить их на несколько документов?';pl = 'Przyjęcia zewnętrzne mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los recibos de mercancías tienen diferentes %1 en el documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los recibos de mercancías tienen diferentes %1 en el documento. ¿Quiere dividirlos para varios documentos?';tr = 'Ambar girişleri belgede farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'I DDT ricevuti hanno diverse %1 nelle intestazioni del documento. Vuoi dividerli in diversi documenti?';de = 'Die Wareneingänge haben unterschiedliche %1 in dem Dokument. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
			DataStructure.DataPresentation);
		
		ShowQueryBox(
			New NotifyDescription("CreateSupplierInvoicesBasedOnGoodsReceipt",
				ThisObject,
				New Structure("GoodsReceiptGroups", DataStructure.GoodsReceiptGroups)),
			MessageText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		If IsDropShipping Then
			OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.DropShipping");
		Else 
			OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.Invoice");
		EndIf;
		
		BasisStructure = New Structure;
		BasisStructure.Insert("GoodsReceiptArray", GoodsReceiptArray);
		BasisStructure.Insert("OperationKind", OperationKind);
		OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;

EndProcedure

Procedure CreateSupplierInvoicesBasedOnGoodsReceipt(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each GoodsReceiptArray In AdditionalParameters.GoodsReceiptGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("GoodsReceiptArray", GoodsReceiptArray);
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CustomsDeclarationGenerationBasedOnSupplierInvoice(SupplierInvoicesListItem) Export

	If SupplierInvoicesListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	InvoicesArray = SupplierInvoicesListItem.SelectedRows;
	
	If InvoicesArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", InvoicesArray[0]);
		OpenForm("Document.CustomsDeclaration.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckSupplierInvoicesKeyAttributes(InvoicesArray);
		If DataStructure.CreateMultipleDocuments Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The invoices have different %1 in document headers. Create multiple customs declarations?'; ru = 'В заголовках инвойсов различаются %1. Создать несколько таможенных деклараций?';pl = 'Faktury mają różne nagłówki w %1 dokumentach. Utwórz wiele deklaracji celnych?';es_ES = 'Las facturas tienen diferentes %1 en los encabezados del documento. ¿Crear las declaraciones múltiples de la aduana?';es_CO = 'Las facturas tienen diferentes %1 en los encabezados del documento. ¿Crear las declaraciones múltiples de la aduana?';tr = 'Faturalar belge başlıklarında farklı %1 sahiptir. Birden fazla gümrük beyannamesini oluştur?';it = 'Le fatture hanno %1 differenti nell''intestazione documento. Create dichiarazioni doganali multiple?';de = 'Die Rechnungen haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Mehrere Zollanmeldungen erstellen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateCustomsDeclaration", 
					ThisObject,
					New Structure("InvoicesGroups", DataStructure.SupplierInvoiceGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure();
			BasisStructure.Insert("ArrayOfSupplierInvoices", InvoicesArray);
			OpenForm("Document.CustomsDeclaration.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateCustomsDeclaration(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each InvoicesArray In AdditionalParameters.InvoicesGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSupplierInvoices", InvoicesArray);
			OpenForm("Document.CustomsDeclaration.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure PackingSlipGenerationBasedOnSalesOrder(SalesOrdersListItem) Export

	If SalesOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = SalesOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.PackingSlip.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckOrdersAndInvoicesKeyAttributesForGoodsIssue(OrdersArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках заказов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los pedidos tienen diferentes %1 en los encabezados del documento. ¿Quiere dividirlos para varios documentos?';tr = 'Siparişler belge başlıklarında farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Vuoi dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreatePackingSlip",
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.PackingSlip.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreatePackingSlip(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.PackingSlip.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CreditNoteGenerationBasedOnGoodsReceipt(GoodsReceiptListItem) Export

	If TypeOf(GoodsReceiptListItem) = Type("Array") Then
		GoodsReceiptArray = GoodsReceiptListItem;
	Else
		
		If GoodsReceiptListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		GoodsReceiptArray = GoodsReceiptListItem.SelectedRows;
	EndIf;
	
	DataStructure = DriveServer.CheckGoodsReceiptKeyAttributes(GoodsReceiptArray);
	If DataStructure.CreateMultipleInvoices Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The goods receipts have different %1 in document. Do you want to split them into several documents?'; ru = 'В поступлениях товаров различаются %1. Разделить их на несколько документов?';pl = 'Przyjęcia zewnętrzne mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los recibos de mercancías tienen diferentes %1 en el documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los recibos de mercancías tienen diferentes %1 en el documento. ¿Quiere dividirlos para varios documentos?';tr = 'Ambar girişleri belgede farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'I DDT ricevuti hanno diverse %1 nelle intestazioni del documento. Vuoi dividerli in diversi documenti?';de = 'Die Wareneingänge haben unterschiedliche %1 in dem Dokument. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
			DataStructure.DataPresentation);
		
		ShowQueryBox(
			New NotifyDescription("CreateCreditNotesBasedOnGoodsReceipt",
				ThisObject,
				New Structure("GoodsReceiptGroups", DataStructure.GoodsReceiptGroups)),
			MessageText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		BasisStructure = New Structure;
		BasisStructure.Insert("ArrayOfGoodsReceipts", GoodsReceiptArray);
		OpenForm("Document.CreditNote.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;

EndProcedure

Procedure CreateCreditNotesBasedOnGoodsReceipt(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each ArrayOfGoodsReceipts In AdditionalParameters.GoodsReceiptGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfGoodsReceipts", ArrayOfGoodsReceipts);
			OpenForm("Document.CreditNote.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure DebitNoteGenerationBasedOnGoodsIssue(GoodsIssueListItem) Export

	If TypeOf(GoodsIssueListItem) = Type("Array") Then
		GoodsIssueArray = GoodsIssueListItem;
	Else
		
		If GoodsIssueListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		GoodsIssueArray = GoodsIssueListItem.SelectedRows;
	EndIf;
	
	DataStructure = DriveServer.CheckGoodsIssueKeyAttributes(GoodsIssueArray);
	If DataStructure.CreateMultipleInvoices Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The goods issues have different %1 in document. Do you want to split them into several documents?'; ru = 'В отпусках товаров различаются %1. Разделить их на несколько документов?';pl = 'Wydania zewnętrzne różnią się %1 w dokumencie. Chcesz podzielić je na kilka dokumentów?';es_ES = 'Las salidas de mercancías tienen diferentes %1 en el documento. ¿Quiere dividirlas para varios documentos?';es_CO = 'Las emisiones de mercancías tienen diferentes %1 en el documento. ¿Quiere dividirlas para varios documentos?';tr = 'Ambar çıkışı belgede farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Le spedizioni merci hanno diversi %1 nel documento. Vuoi dividerle in diversi documenti?';de = 'Die Warenausgänge haben unterschiedliche %1 in dem Dokument. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
			DataStructure.DataPresentation);
		
		ShowQueryBox(
			New NotifyDescription("CreateDebitNotesBasedOnGoodsIssue", 
				ThisObject,
				New Structure("GoodsIssueGroups", DataStructure.GoodsIssueGroups)),
			MessageText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		BasisStructure = New Structure;
		BasisStructure.Insert("ArrayOfGoodsIssues", GoodsIssueArray);
		OpenForm("Document.DebitNote.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;

EndProcedure

Procedure CreateDebitNotesBasedOnGoodsIssue(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each GoodsIssueArray In AdditionalParameters.GoodsIssueGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfGoodsIssues", GoodsIssueArray);
			OpenForm("Document.DebitNote.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure DebitNoteGenerationBasedOnSupplierInvoice(SupplierInvoiceListItem) Export

	If TypeOf(SupplierInvoiceListItem) = Type("Array") Then
		SupplierInvoiceArray = SupplierInvoiceListItem;
	Else
		
		If SupplierInvoiceListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		SupplierInvoiceArray = SupplierInvoiceListItem.SelectedRows;
	EndIf;
	
	DataStructure = DriveServer.CheckSupplierInvoicesKeyAttributes(SupplierInvoiceArray);
	If DataStructure.CreateMultipleDocuments Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The Supplier invoices have different %1 in document. Do you want to split them into several documents?'; ru = 'В инвойсах поставщика различаются %1. Разделить их на несколько документов?';pl = 'Faktury zakupu mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Las facturas de Proveedor tienen diferentes %1 en el documento. ¿Quiere dividirlas para varios documentos?';es_CO = 'Las facturas del Proveedor tienen diferentes %1 en el documento. ¿Quiere dividirlas para varios documentos?';tr = 'Satın alma faturaları belgede farklı %1 sahip. Bunları birkaç belgeye bölmek ister misiniz? ';it = 'Le fattura fornitori hanno %1 differente nel documento. Volete separarle in più documenti?';de = 'Die Eingangsrechnungen haben unterschiedliche %1 im Dokument. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
			DataStructure.DataPresentation);
		
		ShowQueryBox(
			New NotifyDescription("CreateDebitNotesBasedOnSupplierInvoice", 
				ThisObject,
				New Structure("SupplierInvoiceGroups", DataStructure.SupplierInvoiceGroups)),
			MessageText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		BasisStructure = New Structure;
		BasisStructure.Insert("ArrayOfSupplierInvoices", SupplierInvoiceArray);
		OpenForm("Document.DebitNote.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;

EndProcedure

Procedure CreateDebitNotesBasedOnSupplierInvoice(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each SupplierInvoiceArray In AdditionalParameters.SupplierInvoiceGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSupplierInvoices", SupplierInvoiceArray);
			OpenForm("Document.DebitNote.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CreateGoodsIssueBasedOnSupplierInvoice(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.SupplierInvoiceGroups Do
			OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.PurchaseReturn");
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSupplierInvoices", OrdersArray);
			FillStructure.Insert("OperationType", OperationType);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CreateGoodsIssueBasedOnDebitNote(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each DocumentsArray In AdditionalParameters.DocumentGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfDebitNotes", DocumentsArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CreditNoteGenerationBasedOnSalesInvoice(SalesInvoiceListItem) Export

	If TypeOf(SalesInvoiceListItem) = Type("Array") Then
		ArrayOfSalesInvoices = SalesInvoiceListItem;
	Else
		
		If SalesInvoiceListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		ArrayOfSalesInvoices = SalesInvoiceListItem.SelectedRows;
	EndIf;
	
	DataStructure = DriveServer.CheckSalesInvoicesKeyAttributes(ArrayOfSalesInvoices);
	If DataStructure.CreateMultipleDocuments Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The sales invoices have different %1 in document. Do you want to split them into several documents?'; ru = 'В инвойсах различаются %1. Разделить их на несколько документов?';pl = 'Faktury sprzedaży mają inne znaczenie %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Las facturas de ventas tienen diferentes %1 en el documento. ¿Quiere dividirlas para varios documentos?';es_CO = 'Las facturas de ventas tienen diferentes %1 en el documento. ¿Quiere dividirlas para varios documentos?';tr = 'Satış faturaları belgede farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'Le fatture di vendita hanno diverso %1 nel documento. Separarle in più documenti?';de = 'Die Verkaufsrechnungen haben unterschiedliche %1 im Dokument. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
			DataStructure.DataPresentation);
		
		ShowQueryBox(
			New NotifyDescription("CreateCreditNotesBasedOnSalesInvoice", 
				ThisObject,
				New Structure("SalesInvoiceGroups", DataStructure.SalesInvoiceGroups)),
			MessageText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		BasisStructure = New Structure;
		BasisStructure.Insert("ArrayOfSalesInvoices", ArrayOfSalesInvoices);
		OpenForm("Document.CreditNote.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;

EndProcedure

Procedure CreateCreditNotesBasedOnSalesInvoice(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each ArrayOfSalesInvoices In AdditionalParameters.SalesInvoiceGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesInvoices", ArrayOfSalesInvoices);
			OpenForm("Document.CreditNote.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure GoodsReceiptGenerationBasedOnCreditNote(CreditNotesListItem) Export

	If CreditNotesListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	ArrayOfCreditNotes = CreditNotesListItem.SelectedRows;
	
	If ArrayOfCreditNotes.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", ArrayOfCreditNotes[0]);
		OpenForm("Document.GoodsReceipt.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckCreditNotesKeyAttributes(ArrayOfCreditNotes);
		If DataStructure.CreateMultipleDocuments Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The documents have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках документов различаются %1. Разделить их на несколько документов?';pl = 'Dokumenty mają inne znaczenie %1 w nagłówkach dokumentów. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los documentos tienen diferentes %1 encabezados en el documento. ¿Quiere dividirlos para varios documentos?';es_CO = 'Los documentos tienen diferentes %1 encabezados en el documento. ¿Quiere dividirlos para varios documentos?';tr = 'Belgelerin başlıkları farklı %1 sahiptir. Onları birkaç belgeye bölmek ister misiniz?';it = 'I documenti hanno differente %1 nelle intestazioni del documento. Volete separarli in più documenti?';de = 'Die Dokumente haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsReceiptBasedOnCreditNote",
					ThisObject,
					New Structure("DocumentGroups", DataStructure.DocumentGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("ArrayOfCreditNotes", ArrayOfCreditNotes);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateGoodsReceiptBasedOnSalesInvoice(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each SalesInvoicesArray In AdditionalParameters.SalesInvoiceGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesInvoices", SalesInvoicesArray);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CreateGoodsReceiptBasedOnCreditNote(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each DocumentsArray In AdditionalParameters.DocumentGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfCreditNotes", DocumentsArray);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CreateInventoryTransfer(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfOrders", OrdersArray);
			OpenForm("Document.InventoryTransfer.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure InventoryTransferGenerationBasedOnTransferOrder(OrdersListItem) Export

	If OrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = OrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.InventoryTransfer.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckTransferOrdersKeyAttributes(OrdersArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = NStr("en = 'Transfer orders have different warehouses. Do you want to create several Inventory transfers?'; ru = 'В заказах на перемещение различаются склады. Создать несколько перемещений запасов?';pl = 'Zamówienia przeniesienia mają różne magazyny. Czy chcesz utworzyć kilka przesunięć międzymagazynowych?';es_ES = 'Las órdenes de transferencia tienen diferentes almacenes. ¿Quiere crear varios traslados del inventario?';es_CO = 'Las órdenes de transferencia tienen diferentes almacenes. ¿Quiere crear varias transferencias de inventario?';tr = 'Transfer emirleri farklı depolara sahiptir. Birkaç farklı Stok transferi oluşturmak ister misiniz?';it = 'Gli ordini di trasferimento hanno magazzini differenti. Volete creare più trasferimenti scorte?';de = 'Transportaufträge haben unterschiedliche Lager. Möchten Sie mehrere Bestandsumlagerungen erstellen?'");
						
			ShowQueryBox(
				New NotifyDescription("CreateInventoryTransfer", 
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure();
			BasisStructure.Insert("ArrayOfOrders", OrdersArray);
			OpenForm("Document.InventoryTransfer.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure TaxInvoiceReceivedGenerationBasedOnExpenseReport(ExpenseReportRef) Export
	
	If TypeOf(ExpenseReportRef) <> Type("DocumentRef.ExpenseReport") Then
		Return;
	EndIf;
	
	DataStructure = DriveServer.CheckExpenseReportKeyAttributes(ExpenseReportRef);
	
	If Not DataStructure.Checked Then
		Return;
	EndIf;
	
	If DataStructure.CreateMultipleDocuments Then
		
		MessageText = NStr("en = 'Different suppliers are specified for the expense items in the Expense claim.
				|A single ""Tax invoice received"" cannot be generated.
				|Do you want to generate an individual ""Tax invoice received"" for each supplier?'; 
				|ru = 'В авансовом отчете для статей расходов указаны разные поставщики.
				|Невозможно создать единый документ ""Налоговый инвойс полученный"".
				|Создать отдельный документ ""Налоговый инвойс полученный"" для каждого поставщика?';
				|pl = 'Różni dostawcy są określone dla pozycji rozchodów w raporcie rozchodów.
				|Pojedyńcza ""Otrzymana faktura VAT"" nie może być wygenerowana.
				|Czy chcesz wygenerować indywidualną ""Otrzymaną fakturę VAT"" dla każdego dostawcy?';
				|es_ES = 'Se especifican diferentes proveedores para los artículos de gastos en la reclamación de gastos. 
				|No se puede generar una única ""Factura de impuestos recibida"". 
				|¿Quiere generar una ""Factura de impuestos recibida"" particular para cada proveedor?';
				|es_CO = 'Se especifican diferentes proveedores para los artículos de gastos en la reclamación de gastos. 
				|No se puede generar una única ""Factura fiscal recibida"". 
				|¿Quiere generar una ""Factura fiscal recibida"" individual para cada proveedor?';
				|tr = 'Masraf raporunda masraf öğeleri için farklı tedarikçiler belirtildi.
				|Tek bir ""Alınan vergi faturası"" oluşturulamaz.
				|Her tedarikçi için ayrı ""Alınan vergi faturası"" oluşturmak ister misiniz?';
				|it = 'Sono specificati diversi fornitori per gli elementi di spesa nella Richiesta di spese.
				|Non può essere generata una singola ""Fattura fiscale ricevuta"".
				|Generare una ""Fattura fiscale ricevuta"" individuale per ciascun fornitore?';
				|de = 'Verschiedene Lieferanten sind für die Ausgabenposten in der Kostenabrechnung angegeben.
				|Eine einzige ""Steuerrechnung erhalten"" kann nicht generiert werden.
				|Möchten Sie für jeden Lieferanten eine individuelle ""Steuerrechnung erhalten"" generieren?'");
		
		NotifyDescription = New NotifyDescription("CreateTaxInvoiceReceivedBasedOnExpenseReport",
			ThisObject,
			New Structure("RowsDataArray", DataStructure.RowsDataArray));
		
		ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
		
		Return;
		
	EndIf;
	
	If DataStructure.RowsDataArray.Count() > 0 Then
		FillStructure = New Structure("ExpenseReportData", DataStructure.RowsDataArray[0]);
		OpenForm("Document.TaxInvoiceReceived.ObjectForm", New Structure("Basis", FillStructure));
	EndIf;
	
EndProcedure

Procedure CreateTaxInvoiceReceivedBasedOnExpenseReport(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		For Each RowData In AdditionalParameters.RowsDataArray Do
			FillStructure = New Structure("ExpenseReportData", RowData);
			OpenForm("Document.TaxInvoiceReceived.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure DocumentWIPGenerationVisibility(Items, Item, Statuses) Export
	
	CurrentData 	= Item.CurrentData;
	CompletedStatus = Statuses.CompletedStatus;
	OpenStatus      = Statuses.OpenStatus;
	
	FormCreateBasedOn = Items.Find("FormCreateBasedOn");
	If FormCreateBasedOn = Undefined Then
		Return;
	EndIf;
				
	If CurrentData <> Undefined And CurrentData.Posted Then
		
		FormCreateBasedOn.Visible = True;
		
		SubcontractingVisible = (CurrentData.ProductionMethod = PredefinedValue("Enum.ProductionMethods.Subcontracting"));
		ButtonEnabled = Not (CurrentData.Status = CompletedStatus);
		OpenStatus	  = (Item.CurrentData.Status = OpenStatus);
		IsBasedOnSubcontracting = False;
		If CurrentData.Property("ProductionOrderBasisDocument") Then
			IsBasedOnSubcontracting = (TypeOf(CurrentData.ProductionOrderBasisDocument) = Type("DocumentRef.SubcontractorOrderReceived"));
		EndIf;
		
		For Each ChildButton In FormCreateBasedOn.ChildItems Do
			
			ChildButton.Visible = True;
			
			If SubcontractingVisible Then 
				ChildButton.Visible = ?(ChildButton.Name = "FormDocumentSubcontractorOrderIssuedCreateBasedOn",
					ChildButton.Visible = OpenStatus, False);
			Else
				
				If ChildButton.Name = "FormDocumentProductionTaskGenerateProductionTask"
					Or ChildButton.Name = "FormDocumentInventoryTransferGenerateInventoryTransfer"
					Or ChildButton.Name = "FormDocumentTransferOrderGenerateTransferOrder" Then
					
					ChildButton.Visible = ButtonEnabled;
					
				ElsIf ChildButton.Name = "FormDocumentSubcontractorOrderIssuedCreateBasedOn" Then
					ChildButton.Visible = False;
					
				ElsIf ChildButton.Name = "FormDocumentInventoryReservationCreateBasedOn" Then
					ChildButton.Visible = Not IsBasedOnSubcontracting;
				EndIf;

			EndIf;
		EndDo;
	
	Else
		FormCreateBasedOn.Visible = False;
	EndIf;

EndProcedure

#EndRegion

#Region ProceduresForWorkWithProductsSelectionForm

// Function creates a structure for ProductsSelection data processor
//
Function GetSelectionParameters(OwnerForm, TabularSectionName, DocumentPresentaion = "document", ShowBatch = True, ShowPrice = True, ShowAvailable = True, ShowBundles = False) Export
	
	SelectionParameters = New Structure;
	
	OwnerObject = OwnerForm.Object;
	
	If OwnerObject.Property("Date") Then
		SelectionParameters.Insert("Date", OwnerObject.Date);
	Else
		SelectionParameters.Insert("Date", CommonClient.SessionDate());
	EndIf;
	SelectionParameters.Insert("PricePeriod", SelectionParameters.Date);
	
	If OwnerObject.Property("Company") Then
		SelectionParameters.Insert("Company", OwnerObject.Company);
	Else
		SelectionParameters.Insert("Company", PredefinedValue("Catalog.Companies.EmptyRef"));
	EndIf;
	
	If OwnerObject.Property("StructuralUnit") Then
		SelectionParameters.Insert("StructuralUnit", OwnerObject.StructuralUnit);
	ElsIf OwnerObject.Property("StructuralUnitReserve") Then
		SelectionParameters.Insert("StructuralUnit", OwnerObject.StructuralUnitReserve);
	Else
		SelectionParameters.Insert("StructuralUnit", PredefinedValue("Catalog.BusinessUnits.EmptyRef"));
	EndIf;
	
	If OwnerObject.Property("Cell") 
		AND (TypeOf(OwnerObject.Ref) = Type("DocumentRef.GoodsIssue")
			OR TypeOf(OwnerObject.Ref) = Type("DocumentRef.SalesInvoice")) Then
		
		SelectionParameters.Insert("Cell", OwnerObject.Cell);
		SelectionParameters.Insert("FilterCellVisible", True);
	Else
		SelectionParameters.Insert("Cell", PredefinedValue("Catalog.Cells.EmptyRef"));
	EndIf;	
	
	DiscountsMarkupsVisible = False;
	If OwnerObject.Property("DiscountMarkupKind") Then                                      
		SelectionParameters.Insert("DiscountMarkupKind", OwnerObject.DiscountMarkupKind);
		DiscountsMarkupsVisible = True;
	EndIf;
	SelectionParameters.Insert("DiscountsMarkupsVisible", DiscountsMarkupsVisible);
	
	If OwnerObject.Property("PriceKind") Then
		SelectionParameters.Insert("PriceKind", OwnerObject.PriceKind);
	Else
		SelectionParameters.Insert("PriceKind", PredefinedValue("Catalog.PriceTypes.EmptyRef"));
	EndIf;
	
	If OwnerObject.Property("DocumentCurrency") Then
		SelectionParameters.Insert("DocumentCurrency", OwnerObject.DocumentCurrency);
	Else
		SelectionParameters.Insert("DocumentCurrency", Undefined);
	EndIf;

	If OwnerObject.Property("AmountIncludesVAT") Then
		SelectionParameters.Insert("AmountIncludesVAT", OwnerObject.AmountIncludesVAT);
	EndIf;
	
	If OwnerObject.Property("VATTaxation") Then
		SelectionParameters.Insert("VATTaxation", OwnerObject.VATTaxation);
	EndIf;
	
	SelectionParameters.Insert("OwnerFormUUID", OwnerForm.UUID);
	
	If ValueIsFilled(OwnerObject.Ref) Then
		DocumentPresentaion = "" + OwnerObject.Ref;
	EndIf;
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Select products for %1'; ru = 'Подбор номенклатуры для документа %1';pl = 'Wybierz produkty dla %1';es_ES = 'Seleccionar productos para %1';es_CO = 'Seleccionar productos para %1';tr = '%1 için ürünleri seçin';it = 'Selezionare articoli per %1';de = 'Produkte auswählen für %1'"),
																	DocumentPresentaion);
	SelectionParameters.Insert("Title", Title);
	
	//Products type
	ProductsType = New ValueList;
	ProductsColumn = OwnerForm.Items.Find(TabularSectionName + "Products");
	If ProductsColumn  <> Undefined Then
		For Each ArrayElement In ProductsColumn.ChoiceParameters Do
			If ArrayElement.Name = "Filter.ProductsType" Then
				If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
					For Each FixArrayItem In ArrayElement.Value Do
						ProductsType.Add(FixArrayItem);
					EndDo; 
				Else
					ProductsType.Add(ArrayElement.Value);
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	SelectionParameters.Insert("ProductsType", ProductsType);
	
	DiscountCardVisible = False;
	If OwnerObject.Property("DiscountCard") Then
		DiscountCardVisible = True;
		If TypeOf(OwnerObject) = Type("DocumentRef.SalesOrder") Then
			If OwnerObject.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForProcessing") Then
				DiscountCardVisible = False;
			EndIf;
		ElsIf TypeOf(OwnerObject) = Type("DocumentRef.SalesInvoice") Then
			DiscountCardVisible = False;
		EndIf;
		
		If DiscountCardVisible Then
			SelectionParameters.Insert("DiscountCard", OwnerObject.DiscountCard);
			If OwnerObject.Property("DiscountPercentByDiscountCard") Then
				SelectionParameters.Insert("DiscountPercentByDiscountCard", OwnerObject.DiscountPercentByDiscountCard);
			EndIf;
		EndIf;
	EndIf;
	SelectionParameters.Insert("DiscountCardVisible", DiscountCardVisible);
	
	If OwnerObject.Property(TabularSectionName) Then
		TabularSection = OwnerObject[TabularSectionName];
		TotalItems = TabularSection.Count();
		If TotalItems > 0 Then
			If TabularSection[0].Property("Total") Then
				SelectionParameters.Insert("TotalItems", TotalItems);
				SelectionParameters.Insert("TotalAmount", TabularSection.Total("Total"));
			EndIf;
		EndIf; 
	EndIf;
	
	SelectionParameters.Insert("ShowBatch",		ShowBatch);
	SelectionParameters.Insert("ShowPrice",		ShowPrice);
	SelectionParameters.Insert("ShowAvailable",	ShowAvailable);
	SelectionParameters.Insert("ShowBundles",	ShowBundles);
	SelectionParameters.Insert("TabularSectionName", TabularSectionName);
	
	Return SelectionParameters;
	
EndFunction

#EndRegion

#Region ProceduresForWorkWithVariantsSelectionForm

Function GetMatrixParameters(OwnerForm, TabularSectionName, ShowPrice, VariantFilter = Undefined) Export
	
	SelectionParameters = New Structure;
	
	OwnerObject = OwnerForm.Object;
	
	If OwnerObject.Property("Date") Then
		SelectionParameters.Insert("Date", OwnerObject.Date);
	Else
		SelectionParameters.Insert("Date", CommonClient.SessionDate());
	EndIf;
	SelectionParameters.Insert("PricePeriod", SelectionParameters.Date);
	
	If OwnerObject.Property("Company") Then
		SelectionParameters.Insert("Company", OwnerObject.Company);
	Else
		SelectionParameters.Insert("Company", PredefinedValue("Catalog.Companies.EmptyRef"));
	EndIf;
	
	If OwnerObject.Property("PriceKind") Then
		SelectionParameters.Insert("PriceKind", OwnerObject.PriceKind);
	Else
		SelectionParameters.Insert("PriceKind", PredefinedValue("Catalog.PriceTypes.EmptyRef"));
	EndIf;
	
	If OwnerObject.Property("DocumentCurrency") Then
		SelectionParameters.Insert("DocumentCurrency", OwnerObject.DocumentCurrency);
	Else
		SelectionParameters.Insert("DocumentCurrency", Undefined);
	EndIf;
	
	If OwnerObject.Property("StructuralUnit") Then
		SelectionParameters.Insert("StructuralUnit", OwnerObject.StructuralUnit);
	ElsIf OwnerObject.Property("StructuralUnitReserve") Then
		SelectionParameters.Insert("StructuralUnit", OwnerObject.StructuralUnitReserve);
	Else
		SelectionParameters.Insert("StructuralUnit", PredefinedValue("Catalog.BusinessUnits.EmptyRef"));
	EndIf;
	
	If OwnerObject.Property("AmountIncludesVAT") Then
		SelectionParameters.Insert("AmountIncludesVAT", OwnerObject.AmountIncludesVAT);
	EndIf;
	
	If OwnerObject.Property("VATTaxation") Then
		SelectionParameters.Insert("VATTaxation", OwnerObject.VATTaxation);
	EndIf;
	
	If OwnerObject.Property("DiscountMarkupKind") Then
		SelectionParameters.Insert("DiscountMarkupKind", OwnerObject.DiscountMarkupKind);
	Else
		SelectionParameters.Insert("DiscountMarkupKind", PredefinedValue("Catalog.DiscountTypes.EmptyRef"));
	EndIf;
	
	SelectionParameters.Insert("OwnerFormUUID", OwnerForm.UUID);
	CurrentRow = OwnerForm.Items[TabularSectionName].CurrentData;
	SelectionParameters.Insert("Products", CurrentRow.Products);
	
	SelectedProducts = New Map;
	ProductsPrices = New Map;
	
	ShowNotificationAboutPrices = False;
	
	If OwnerObject.Property(TabularSectionName) Then
		TabularSection = OwnerObject[TabularSectionName];
		
		Filter = New Structure;
		Filter.Insert("Products", SelectionParameters.Products);
		
		If VariantFilter <> Undefined Then
			Filter.Insert("Variant", VariantFilter);
		EndIf;
		
		FoundRows = TabularSection.FindRows(Filter);
		
		For Each FoundRow In FoundRows Do
			
			FillPrice = FoundRow.Property("Price");
			
			SelectedProduct = SelectedProducts.Get(FoundRow.Characteristic);
			ProductsPrice = ProductsPrices.Get(FoundRow.Characteristic);
			If SelectedProduct = Undefined Then
				SelectedProducts.Insert(FoundRow.Characteristic, FoundRow.Quantity);
				If FillPrice Then
					ProductsPrices.Insert(FoundRow.Characteristic, FoundRow.Price);
				EndIf;
			Else
				SelectedProducts.Insert(FoundRow.Characteristic, SelectedProduct + FoundRow.Quantity);
				If FillPrice And ProductsPrice <> FoundRow.Price Then
					ShowNotificationAboutPrices = True;
				EndIf;
			EndIf;
			
		EndDo;
		
	ElsIf CommonClientServer.HasAttributeOrObjectProperty(OwnerForm, TabularSectionName) Then
		
		TabularSection = OwnerForm[TabularSectionName];
		
		Filter = New Structure;
		Filter.Insert("Products", SelectionParameters.Products);
		
		If VariantFilter <> Undefined Then
			Filter.Insert("Variant", VariantFilter);
		EndIf;
		
		FoundRows = TabularSection.FindRows(Filter);
		
		For Each FoundRow In FoundRows Do
			
			FillPrice = FoundRow.Property("Price");
			
			SelectedProduct = SelectedProducts.Get(FoundRow.Characteristic);
			ProductsPrice = ProductsPrices.Get(FoundRow.Characteristic);
			
			QuantityName = ?(FoundRow.Property("TotalQuantity"), "TotalQuantity", "Quantity");
			
			If SelectedProduct = Undefined Then
				SelectedProducts.Insert(FoundRow.Characteristic, FoundRow[QuantityName]);
				If FillPrice Then
					ProductsPrices.Insert(FoundRow.Characteristic, FoundRow.Price);
				EndIf;
			Else
				SelectedProducts.Insert(FoundRow.Characteristic, SelectedProduct + FoundRow[QuantityName]);
				If FillPrice And ProductsPrice <> FoundRow.Price Then
					ShowNotificationAboutPrices = True;
				EndIf;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	SelectionParameters.Insert("ShowNotificationAboutPrices",	ShowNotificationAboutPrices);
	SelectionParameters.Insert("SelectedProducts",				SelectedProducts);
	SelectionParameters.Insert("ProductsPrices",				ProductsPrices);
	SelectionParameters.Insert("TabularSectionName",			TabularSectionName);
	SelectionParameters.Insert("ShowPrice",						ShowPrice);
	
	Return SelectionParameters;
	
EndFunction

Function UseMatrixForm(Product) Export
	
	Return DriveServer.UseMatrixForm(Product);
	
EndFunction

Function UseMatrixFormWithCategory(ProductsCategory) Export
	
	Return DriveServer.UseMatrixFormWithCategory(ProductsCategory);
	
EndFunction

#EndRegion

// Displays result of operation execution.
//
// Displays the server result on
// the client, does not show mid-stages. - dialogs etc.
//
// See also:
//   StandardSubsystemsClientServer.NewExecutionResult()
//   StandardSubsystemsClientServer.NotifyDynamicLists()
//   StandardSubsystemsClientServer.DisplayWarning()
//   StandardSubsystemsClientServer.ShowMessage()
//   StandardSubsystemsClientServer.DisplayNotification()
//   StandardSubsystemsClientServer.CollapseTreeNodes()
//
// Parameters:
//   Form - ClientApplicationForm - Form for which output is required.
//   Result - Structure - Operation execution result to be shown.
//       * OutputNotification - Structure - Popup alert.
//           ** Usage - Boolean - Output alert.
//           ** Title     - String - Notification title.
//           ** Text         - String - Notification text.
//           ** Refs        - String - Text navigation hyperlink.
//           ** Picture      - Picture - Notification picture.
//       * MessageOutput - Structure - Form message bound to the attribute.
//           ** Usage       - Boolean - Output message.
//           ** Text               - String - Message text.
//           ** PathToFormAttribute - String - Path attribute of the form to which the message applies.
//       * WarningOutput - Structure - Warning window locking the entire interface.
//           ** Usage       - Boolean - Output warning.
//           ** Title           - String - Window title.
//           ** Text               - String - Notification text.
//           ** ErrorsText         - String - Optional. Texts of errors that the user
//                                             can view if necessary.
//           ** PathToFormAttribute - String - Optional. Path to the form attribute
//                                             which value caused an error.
//       * FormsNotification - Structure, Array from Structure - cm. help k method global context Notify().
//           ** Use - Boolean - Alert the form opening.
//           ** EventName    - String - Event name used for primary message identification
//                                       by the receiving forms.
//           ** Parameter      - Arbitrary - Set of data used by the receiving
//                                             form for the content update.
//           ** Source      - Arbitrary - Notification source, for example, form-source.
//       * DynamictListsAlert - Structure - cm. help k method global context
//                                                     NotifyChanged().
//           ** Use - Boolean - Notify the dynamic lists.
//           ** ReferenceOrType  - Arbitrary - Ref, type or type array that are to be updated.
//   EndProcessor - NotifyDescription - Description of procedure that will be called
//                                               after finishing display (with value Undefined).
//
Procedure ShowExecutionResult(Form, Result, EndProcessor = Undefined) Export
	
	If TypeOf(Result) <> Type("Structure") AND TypeOf(Result) <> Type("FixedStructure") Then
		Return;
	EndIf;
	
	EndProcessorWillCompleted = False;
	
	If Result.Property("OutputNotification") AND Result.OutputNotification.Use Then
		Notification = Result.OutputNotification;
		ShowUserNotification(Notification.Title, Notification.Ref, Notification.Text, Notification.Picture);
	EndIf;
	
	If Result.Property("OutputMessages") AND Result.OutputMessages.Use Then
		Message = New UserMessage;
		If TypeOf(Form) = Type("ClientApplicationForm") Then
			Message.TargetID = Form.UUID;
		EndIf;
		Message.Text = Result.OutputMessages.Text;
		Message.Field  = Result.OutputMessages.PathToFormAttribute;
		Message.Message();
	EndIf;
	
	If Result.Property("OutputWarning") AND Result.OutputWarning.Use Then
		OutputWarning = Result.OutputWarning;
		If ValueIsFilled(OutputWarning.ErrorsText) Then
			Buttons = New ValueList;
			Buttons.Add(1, NStr("en = 'More...'; ru = 'Дополнительно...';pl = 'Więcej…';es_ES = 'Más...';es_CO = 'Más...';tr = 'Daha fazla...';it = 'Di Più...';de = 'Mehr...'"));
			If TypeOf(Form) = Type("ClientApplicationForm") AND ValueIsFilled(OutputWarning.PathToFormAttribute) Then
				Buttons.Add(2, NStr("en = 'Go to attribute'; ru = 'Перейти к реквизиту';pl = 'Przejdź do atrybutu';es_ES = 'Ir al atributo';es_CO = 'Ir al atributo';tr = 'Özniteliğe git';it = 'Vai a attribuire';de = 'Gehe zum Attribut'"));
			EndIf;
			Buttons.Add(0, NStr("en = 'Continue'; ru = 'Продолжить';pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("OutputWarning",   OutputWarning);
			AdditionalParameters.Insert("Form",                 Form);
			AdditionalParameters.Insert("EndProcessor", EndProcessor);
			Handler = New NotifyDescription("ShowExecutionResultEnd", ThisObject, AdditionalParameters);
			
			ShowQueryBox(Handler, OutputWarning.Text, Buttons, , 1, OutputWarning.Title);
			EndProcessorWillCompleted = True;
		Else
			ReturnResultAfterShowWarning(OutputWarning.Text, EndProcessor, Undefined, OutputWarning.Title);
			EndProcessorWillCompleted = True;
		EndIf;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		If TypeOf(Result.NotificationForms) = Type("Structure") Or TypeOf(Result.NotificationForms) = Type("FixedStructure") Then
			NotificationForms = Result.NotificationForms;
			If NotificationForms.Use Then
				Notify(NotificationForms.EventName, NotificationForms.Parameter, NotificationForms.Source);
			EndIf;
		Else
			For Each NotificationForms In Result.NotificationForms Do
				If NotificationForms.Use Then
					Notify(NotificationForms.EventName, NotificationForms.Parameter, NotificationForms.Source);
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	If Result.Property("NotifyDynamictLists") AND Result.NotifyDynamictLists.Use Then
		If TypeOf(Result.NotifyDynamictLists.ReferenceOrType) = Type("Array") Then
			For Each ReferenceOrType In Result.NotifyDynamictLists.ReferenceOrType Do
				NotifyChanged(ReferenceOrType);
			EndDo;
		Else
			NotifyChanged(Result.NotifyDynamictLists.ReferenceOrType);
		EndIf;
	EndIf;
	
	If Result.Property("ExpandableNodes") Then
		For Each ExpandableNode In Result.ExpandableNodes Do
			ItemTable = Form.Items[ExpandableNode.TableName];
			If ExpandableNode.Identifier = "*" Then
				Nodes = Form[ExpandableNode.TableName].GetItems();
				For Each Node In Nodes Do
					ItemTable.Expand(Node.GetID(), ExpandableNode.WithSubordinate);
				EndDo;
			Else
				ItemTable.Expand(ExpandableNode.Identifier, ExpandableNode.WithSubordinate);
			EndIf;
		EndDo;
	EndIf;
	
	If Not EndProcessorWillCompleted AND EndProcessor <> Undefined Then
		ExecuteNotifyProcessing(EndProcessor, Undefined);
	EndIf;
	
EndProcedure

// Handler of question response when displaying the execution result.
//
Procedure ShowExecutionResultEnd(Response, Result) Export
	
	EndProcessorWillCompleted = False;
	If TypeOf(Response) = Type("Number") Then
		If Response = 1 Then
			FullText = String(Result.OutputWarning.Text) + Chars.LF + Chars.LF + Result.OutputWarning.ErrorsText;
			Title = Result.OutputWarning.Title;
			If IsBlankString(Title) Then
				Title = NStr("en = 'Explanation'; ru = 'Расшифровка';pl = 'Wyjaśnienie';es_ES = 'Explicación';es_CO = 'Explicación';tr = 'Açıklama';it = 'Decodificare';de = 'Erklärung'");
			EndIf;
			Handler = New NotifyDescription("ShowExecutionResultEnd", ThisObject, Result);
			ShowInputString(Handler, FullText, Title, , True);
			EndProcessorWillCompleted = True;
		ElsIf Response = 2 Then
			Message = New UserMessage;
			Message.TargetID = Result.Form.UUID;
			Message.Text = Result.OutputWarning.Text;
			Message.Field  = Result.OutputWarning.PathToFormAttribute;
			Message.Message();
		EndIf;
	EndIf;
	
	If Not EndProcessorWillCompleted AND Result.EndProcessor <> Undefined Then
		ExecuteNotifyProcessing(Result.EndProcessor, Undefined);
	EndIf;
	
EndProcedure

// Shows a warning dialog, once it is closed, calls a handler with the set result.
Procedure ReturnResultAfterShowWarning(WarningText, Handler, Result, Title = Undefined, Timeout = 0) Export
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Handler", Handler);
	HandlerParameters.Insert("Result", Result);
	Handler = New NotifyDescription("ReturnResultAfterSimpleDialogClosing", ThisObject, HandlerParameters);
	ShowMessageBox(Handler, WarningText, Timeout, Title);
EndProcedure

#Region FirstLaunch

Procedure BeforeStart(Parameters) Export
	
	ClientWorkParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If Not ClientWorkParameters.DataSeparationEnabled Then
		
		If ValueIsFilled(LaunchParameter) And StrFind(LaunchParameter, "DisableUpdateConfigurationPackage") > 0 Then
			LaunchParameterIsEmpty = False;
		Else
			LaunchParameterIsEmpty = True;
		EndIf;
		
		If Not ClientWorkParameters.FirstLaunchPassed 
			Or (ClientWorkParameters.UpdateConfigurationPackage And LaunchParameterIsEmpty) Then
			
			If ClientWorkParameters.UpdateConfigurationPackage Then
				Parameters.Insert("UpdateConfigurationPackage", ClientWorkParameters.UpdateConfigurationPackage);
			EndIf;
			
			Parameters.Insert("FirstLaunchPassed", ClientWorkParameters.FirstLaunchPassed);
			Parameters.InteractiveHandler = New NotifyDescription("OpenFirstLaunch", ThisObject, Parameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OpenFirstLaunch(Parameters, AdditionalParameters) Export
	
	NotifyDescription = New NotifyDescription ("CompletionProcessing", Thisobject, Parameters);
	
	FormParameters = New Structure();
	If Parameters.Property("FirstLaunchPassed") Then
		FormParameters.Insert("FirstLaunchPassed", Parameters.FirstLaunchPassed);
	EndIf;
	If Parameters.Property("UpdateConfigurationPackage") Then
		FormParameters.Insert("UpdateConfigurationPackage", True);
	EndIf;

	Form = OpenForm("DataProcessor.FirstLaunch.Form", FormParameters,,,,, NotifyDescription);
	
EndProcedure

Procedure CompletionProcessing(Result, Parameters) Export
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
EndProcedure

#EndRegion

#Region AfterStartHandlers

Procedure ShowMessageAboutUserTemplateUsed() Export
	
	ObjectAreas = New ValueList;
	
	SpreadsheetDocument = DriveServerCall.MessageTemplateAboutUserTemplateUsed();
	If SpreadsheetDocument = Undefined Then
		Return;
	EndIf;
	
	PrintFormID = "UserTemplateUsed";
	
	PrintFormsCollection = PrintManagementClient.NewPrintFormsCollection(PrintFormID);
	
	PrintForm = PrintManagementClient.PrintFormDetails(PrintFormsCollection, PrintFormID);
	PrintForm.TemplateSynonym = NStr("en = 'User print templates have been disabled'; ru = 'Пользовательские шаблоны печати отключены';pl = 'Szablony drukowania są odłączone';es_ES = 'Se han desactivado los modelos de la versión impresa del usuario';es_CO = 'Se han desactivado los modelos de la versión impresa del usuario';tr = 'Kullanıcı yazdırma şablonları devre dışı bırakıldı';it = 'I modelli di stampa utente sono stati disabilitati';de = 'Benutzerdruckvorlagen wurden deaktiviert'");
	PrintForm.SpreadsheetDocument = SpreadsheetDocument;
	PrintForm.PrintFormFileName = NStr("en = 'User print templates have been disabled'; ru = 'Пользовательские шаблоны печати отключены';pl = 'Szablony drukowania są odłączone';es_ES = 'Se han desactivado los modelos de la versión impresa del usuario';es_CO = 'Se han desactivado los modelos de la versión impresa del usuario';tr = 'Kullanıcı yazdırma şablonları devre dışı bırakıldı';it = 'I modelli di stampa utente sono stati disabilitati';de = 'Benutzerdruckvorlagen wurden deaktiviert'");
	
	PrintObjects = New ValueList;
	
	UniqueKey = String(New UUID);
	
	OpeningParameters = New Structure("PrintManagerName,TemplatesNames,CommandParameter,PrintParameters");
	OpeningParameters.CommandParameter = New Array;
	
	OpeningParameters.PrintParameters = New Structure;
	OpeningParameters.PrintParameters.Insert("FormCaption", NStr("en = 'User print templates have been disabled'; ru = 'Пользовательские шаблоны печати отключены';pl = 'Szablony drukowania są odłączone';es_ES = 'Se han desactivado los modelos de la versión impresa del usuario';es_CO = 'Se han desactivado los modelos de la versión impresa del usuario';tr = 'Kullanıcı yazdırma şablonları devre dışı bırakıldı';it = 'I modelli di stampa utente sono stati disabilitati';de = 'Benutzerdruckvorlagen wurden deaktiviert'"));
	
	OpeningParameters.Insert("PrintFormsCollection", PrintFormsCollection);
	OpeningParameters.Insert("PrintObjects", PrintObjects);
	
	OpenForm("CommonForm.PrintDocuments", OpeningParameters, Undefined, UniqueKey);

EndProcedure

#EndRegion

#Region ProceduresForWorkDuplicatesCheckingForm

// Function creates a structure for DuplicateChecking data processor
//
Function GetDuplicateCheckingParameters(OwnerForm, CIAttributeName = "") Export
	
	DuplicateCheckingParameters = New Structure;
	
	OwnerObject = OwnerForm.Object;
	
	DuplicateCheckingParameters.Insert("Ref",	OwnerObject.Ref);
	DuplicateCheckingParameters.Insert("DeletionMark",	OwnerObject.DeletionMark);
	
	If OwnerObject.Property("Description") Then
		DuplicateCheckingParameters.Insert("Description", OwnerObject.Description);
	EndIf;

	If OwnerObject.Property("DescriptionFull") Then
		DuplicateCheckingParameters.Insert("DescriptionFull", OwnerObject.DescriptionFull);
	EndIf;
	
	If OwnerObject.Property("VATNumber") Then
		DuplicateCheckingParameters.Insert("VATNumber", OwnerObject.VATNumber);
	EndIf;
	
	If OwnerObject.Property("RegistrationNumber") Then
		DuplicateCheckingParameters.Insert("RegistrationNumber", OwnerObject.RegistrationNumber);
	EndIf;
	
	If OwnerObject.Property("SKU") Then
		DuplicateCheckingParameters.Insert("SKU", OwnerObject.SKU);
	EndIf;
	
	If OwnerObject.Property("Counterparty") Then
		DuplicateCheckingParameters.Insert("Counterparty", OwnerObject.Counterparty);
	EndIf;

	If OwnerObject.Property("Owner") Then
		DuplicateCheckingParameters.Insert("Owner", OwnerObject.Owner);
	EndIf;
	
	If ValueIsFilled(CIAttributeName) Then
		DuplicateCheckingParameters.Insert("ContactInformation", OwnerForm[CIAttributeName]);
	EndIf;
	
	Return DuplicateCheckingParameters;
	
EndFunction

#EndRegion

#Region WorkWithStatusesInList

// Form command handler.
//
// Parameters:
//   Command - FormCommand - a running command.
//   Source - FormTable, FormDataStructure - an object or a form list.
//   CatalogStatusesType - String - a name of catalog with statuses for documents in list.
//
Procedure ExecuteChangeStatusCommand(Command, Source, CatalogStatusesType) Export
	
	OrdersArray = CheckGetSelectedRefsInList(Source);
	If OrdersArray.Count() > 0 Then
		
		CommandName = Command.Name;
		DriveServer.ChangeOrdersStatuses(OrdersArray, CommandName, CatalogStatusesType);
		Source.Refresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithDatePrecision

Function FormatDateByPrecision(Date, Precision, Adjust = False) Export
	
	If Not ValueIsFilled(Date) Then
		Return "";
	EndIf;
	
	If Adjust Then
		
		AdjustedDate = DriveClientServer.AdjustDateByPrecision(Date, Precision);
		
	Else
		
		AdjustedDate = Date;
		
	EndIf;
	
	FormatString = DriveClientServer.DatePrecisionFormatString(Precision);
	
	If IsBlankString(FormatString) Then
		
		Return String(AdjustedDate);
		
	Else
		
		Return Format(AdjustedDate, FormatString);
		
	EndIf;
	
EndFunction

#EndRegion

#Region Private

Procedure ProcessDateDiffQueryBox(Result, Parameters) Export
	
	Form = Parameters.Form;
	AttributeName = Parameters.AttributeName;
	If Result = DialogReturnCode.Yes Then
		Form.Object.Number = "";
		ProcedureName = Parameters.ProcedureName;
		If IsBlankString(ProcedureName) Then
			Form[AttributeName] = Form.Object.Date;
		Else
			Form.AttachIdleHandler(ProcedureName, 0.2, True);
		EndIf;
	Else
		Form.Object.Date = Form[AttributeName];
	EndIf;
	
EndProcedure

#EndRegion