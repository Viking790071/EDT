
#Region EventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;

	If Parameters.Key = Undefined Or Parameters.Key.IsEmpty() Then
		Object.BlocksDelimiter1 = "^";
		Object.BlocksDelimiter2 = "=";
		Object.BlocksDelimiter3 = "=";
		
		Object.CodeLength1 = 79;
		Object.CodeLength2 = 40;
		Object.CodeLength3 = 107;
		
		Object.Prefix1 = "%";
		Object.Prefix2 = ";";
		Object.Prefix3 = ";";
		
		Object.Suffix1 = "?";
		Object.Suffix2 = "?";
		Object.Suffix3 = "?";
		
		Object.TrackAvailability1 = True;
		Object.TrackAvailability2 = True;
		Object.TrackAvailability3 = True;
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// Peripherals
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		ErrorDescription = "";

		SupporTypesVO = New Array();
		SupporTypesVO.Add("MagneticCardReader");

		If Not EquipmentManagerClient.ConnectEquipmentByType(UUID, SupporTypesVO, ErrorDescription) Then
			MessageText = NStr("en = 'An error occurred while
			                   |connecting peripherals: ""%ErrorDescription%"".'; 
			                   |ru = 'При подключении оборудования
			                   |произошла ошибка: ""%ErrorDescription%"".';
			                   |pl = 'Wystąpił błąd podczas
			                   |podłączania urządzeń peryferyjnych: ""%ErrorDescription%"".';
			                   |es_ES = 'Ha ocurrido un error al
			                   |conectar los periféricos: ""%ErrorDescription%"".';
			                   |es_CO = 'Ha ocurrido un error al
			                   |conectar los periféricos: ""%ErrorDescription%"".';
			                   |tr = 'Çevre birimleri bağlanırken
			                   |hata oluştu: ""%ErrorDescription%"".';
			                   |it = 'Si è registrato un errore durante
			                   |la connessione periferiche: ""%ErrorDescription%"".';
			                   |de = 'Beim Anschluss von
			                   |Peripheriegeräten ist ein Fehler aufgetreten: ""%ErrorDescription%"".'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	// End Peripherals
	
	SetTracksEnabled();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "TracksData" Then
			If Parameter[1] = Undefined Then
				TracksData = Parameter[0];
			Else
				TracksData = Parameter[1][1];
			EndIf;
			
			// Display data that was read
			Track1 = TracksData[0];
			Track2 = TracksData[1];
			Track3 = TracksData[2];
			Object.CodeLength1 = StrLen(Track1);
			Object.CodeLength2 = StrLen(Track2);
			Object.CodeLength3 = StrLen(Track3);
			Object.TrackAvailability1 = Not (StrLen(Track1) = 0);
			Object.TrackAvailability2 = Not (StrLen(Track2) = 0);
			Object.TrackAvailability3 = Not (StrLen(Track3) = 0);
			SetTracksEnabled();
			
			Modified = True;
			
		EndIf;
	EndIf;
	// End Peripherals
EndProcedure

&AtClient
Procedure OnClose(Exit)
	// Peripherals
	SupporTypesVO = New Array();
	SupporTypesVO.Add("MagneticCardReader");

	EquipmentManagerClient.DisableEquipmentByType(UUID, SupporTypesVO);
	// End Peripherals
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// Checking on field existence
	ClearMessages();
	FieldCounter = 0;
	If Object.TrackAvailability1 Then
		FieldCounter = FieldCounter + Object.TrackFields1.Count();
	EndIf;
	If Object.TrackAvailability2 Then
		FieldCounter = FieldCounter + Object.TrackFields2.Count();
	EndIf;
	If Object.TrackAvailability3 Then
		FieldCounter = FieldCounter + Object.TrackFields3.Count();
	EndIf;
	If FieldCounter = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'Not a single field was not added to the any of available tracks.'; ru = 'Не добавлено ни одного поля ни в одной из доступных дорожек.';pl = 'Żadne z pól nie zostało dodane do żadnego z dostępnych ciągów.';es_ES = 'Ni un campo se ha agregado a ninguno de los seguimientos disponibles.';es_CO = 'Ni un campo se ha agregado a ninguno de los seguimientos disponibles.';tr = 'Mevcut parçalardan hiçbirine tek bir alan eklenmedi.';it = 'Non un singolo campo non è stato aggiunto al qualsiasi dei brani disponibili.';de = 'Es wurde kein einziges Feld zu den verfügbaren Spuren hinzugefügt.'"), , , , Cancel);
	EndIf;
	
	ControlOfFieldsUniqueness(Cancel);
	
EndProcedure

&AtClient
Procedure ExternalEvent(Source, Event, Data)
	
	If IsInputAvailable() Then
		
		DetailsEvents = New Structure();
		ErrorDescription  = "";
		DetailsEvents.Insert("Source", Source);
		DetailsEvents.Insert("Event",  Event);
		DetailsEvents.Insert("Data",   Data);
		
		Result = EquipmentManagerClient.GetEventFromDevice(DetailsEvents, ErrorDescription);
		If Result = Undefined Then 
			MessageText = NStr("en = 'An error occurred during the processing of external event from the device:'; ru = 'При обработке внешнего события от устройства произошла ошибка:';pl = 'Wystąpił błąd podczas przetwarzania wydarzenia zewnętrznego z urządzenia:';es_ES = 'Ha ocurrido un error durante el procesamiento del evento externo desde el dispositivo:';es_CO = 'Ha ocurrido un error durante el procesamiento del evento externo desde el dispositivo:';tr = 'Harici olayın cihazdan işlenmesi sırasında bir hata oluştu:';it = 'Si è verificato un errore durante l''elaborazione dell''evento esterno dal dispositivo:';de = 'Bei der Verarbeitung eines externen Ereignisses vom Gerät ist ein Fehler aufgetreten:'")
								+ Chars.LF + ErrorDescription;
			CommonClientServer.MessageToUser(MessageText);
		Else
			NotificationProcessing(Result.EventName, Result.Parameter, Result.Source);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GetPrefix1(Command)
	If StrLen(Items.Track1.SelectedText) > 0 Then
		Object.Prefix1 = Items.Track1.SelectedText;
	Else
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetPrefix2(Command)
	If StrLen(Items.Track2.SelectedText) > 0 Then
		Object.Prefix2 = Items.Track2.SelectedText;
	Else
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetPrefix3(Command)
	If StrLen(Items.Track3.SelectedText) > 0 Then
		Object.Prefix3 = Items.Track3.SelectedText;
	Else
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetSuffix1(Command)
	If StrLen(Items.Track1.SelectedText) > 0 Then
		Object.Suffix1 = Items.Track1.SelectedText;
	Else
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetSuffix2(Command)
	If StrLen(Items.Track2.SelectedText) > 0 Then
		Object.Suffix2 = Items.Track2.SelectedText;
	Else
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetSuffix3(Command)
	If StrLen(Items.Track3.SelectedText) > 0 Then
		Object.Suffix3 = Items.Track3.SelectedText;
	Else
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetDelimiter1(Command)
	If StrLen(Items.Track1.SelectedText) > 0 Then
		Object.BlocksDelimiter1 = Items.Track1.SelectedText;
	Else
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetDelimiter2(Command)
	If StrLen(Items.Track2.SelectedText) > 0 Then
		Object.BlocksDelimiter2 = Items.Track2.SelectedText;
	Else
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetDelimiter3(Command)
	If StrLen(Items.Track3.SelectedText) > 0 Then
		Object.BlocksDelimiter3 = Items.Track3.SelectedText;
	Else
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
	EndIf;
EndProcedure

&AtClient
Procedure GetField1End(Result, Parameters) Export
	
	Items.TrackFields1.AddRow();
	NewField = Items.TrackFields1.CurrentData;
	NewField.BlockNumber = Result.BlockNumber;
	NewField.FirstFieldSymbolNumber = Result.FirstFieldSymbolNumber;
	NewField.FieldLenght = Result.FieldLenght;
	NewField.Field = PredefinedValue("Enum.MagneticCardsTemplateFields.Code");
	Items.TrackFields1.EndEditRow(False);
	
EndProcedure

&AtClient
Procedure GetField1(Command)
	
	Var NStr, NCol, CStr, CCol;
	
	ClearMessages();
		
	If StrLen(Items.Track1.SelectedText) = 0 Then
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
		Return;
	EndIf;
	
	Notification = New NotifyDescription("GetField1End", ThisObject, );

	Items.Track1.GetTextSelectionBounds(NStr, NCol, CStr, CCol);
	
	DetermineFieldCoordinates(Notification, Track1, Object.Prefix1, Object.Suffix1, Object.BlocksDelimiter1, NCol, CCol);
	
EndProcedure

&AtClient
Procedure GetField2End(Result, Parameters) Export
	
	Items.TrackFields2.AddRow();
	NewField = Items.TrackFields2.CurrentData;
	NewField.BlockNumber = Result.BlockNumber;
	NewField.FirstFieldSymbolNumber = Result.FirstFieldSymbolNumber;
	NewField.FieldLenght = Result.FieldLenght;
	NewField.Field = PredefinedValue("Enum.MagneticCardsTemplateFields.Code");
	Items.TrackFields2.EndEditRow(False);
	
EndProcedure

&AtClient
Procedure GetField2(Command)
	
	Var NStr, NCol, CStr, CCol;
	
	ClearMessages();
	
	If StrLen(Items.Track2.SelectedText) = 0 Then
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
		Return;
	EndIf;
	
	Notification = New NotifyDescription("GetField2End", ThisObject, Parameters);

	Items.Track2.GetTextSelectionBounds(NStr, NCol, CStr, CCol);
	
	DetermineFieldCoordinates(Notification, Track2, Object.Prefix2, Object.Suffix2, Object.BlocksDelimiter2, NCol, CCol);
	
EndProcedure

&AtClient
Procedure GetField3End(Result, Parameters) Export
	
	Items.TrackFields3.AddRow();
	NewField = Items.TrackFields3.CurrentData;
	NewField.BlockNumber = Result.BlockNumber;
	NewField.FirstFieldSymbolNumber = Result.FirstFieldSymbolNumber;
	NewField.FieldLenght = Result.FieldLenght;
	NewField.Field = PredefinedValue("Enum.MagneticCardsTemplateFields.Code");
	Items.TrackFields3.EndEditRow(False);
	
EndProcedure

&AtClient
Procedure GetField3(Command)
	
	Var NStr, NCol, CStr, CCol;
	
	ClearMessages();
	
	If StrLen(Items.Track3.SelectedText) = 0 Then
		ClearMessages();
		CommonClientServer.MessageToUser(NStr("en = 'Use mouse to select the part of the code.'; ru = 'Выделите мышкой участок кода.';pl = 'Użyj myszki, aby wybrać część kodu.';es_ES = 'Utilice el ratón para seleccionar la parte del código.';es_CO = 'Utilice el ratón para seleccionar la parte del código.';tr = 'Kodun bir bölümünü seçmek için imleci kullanın.';it = 'Selezionare parte del codice con il mouse.';de = 'Verwenden Sie die Maus, um den Teil des Codes auszuwählen.'"));
		Return;
	EndIf;
	
	Notification = New NotifyDescription("GetField3End", ThisObject, );

	Items.Track3.GetTextSelectionBounds(NStr, NCol, CStr, CCol);
	
	DetermineFieldCoordinates(Notification, Track3, Object.Prefix3, Object.Suffix3, Object.BlocksDelimiter3, NCol, CCol);
	//
EndProcedure

&AtClient
Procedure DetermineFieldCoordinatesEnd(Result, Context) Export
	
	If Result.Value = DialogReturnCode.No Then
		Context.Result.FieldLenght = 0;
	EndIf;
	
	If Context <> Undefined AND Context.NextAlert <> Undefined Then
		ExecuteNotifyProcessing(Context.NextAlert, Context.Result);
	EndIf;
	
EndProcedure

// Specifies the field coordinates by selected section of the path code.
//
&AtClient
Procedure DetermineFieldCoordinates(Notification, TrackData, Prefix, Suffix, Delimiter, NCol, CCol)
	
	DataRow = TrackData;
	If Not IsBlankString(Prefix)
		AND Prefix = Left(DataRow, StrLen(Prefix)) Then
		DataRow = Right(DataRow, StrLen(DataRow)-StrLen(Prefix)); // cut prefix if any
		NCol = NCol - StrLen(Prefix);
		CCol = CCol - StrLen(Prefix);
		If NCol < 1 Then
			// Selected text overlaps the prefix.
			CommonClientServer.MessageToUser(NStr("en = 'Selected part of the code should not overlap the suffix, prefix or block separator.'; ru = 'Выделенный участок кода не должен пересекаться с суффиксом, префиксом или разделителем блоков.';pl = 'Wybrana część kodu nie powinna nakładać się na sufiks, przedrostek lub separator bloków.';es_ES = 'Parte seleccionada del código no tiene que superponerse al sufijo, el prefijo o el separador de bloque.';es_CO = 'Parte seleccionada del código no tiene que superponerse al sufijo, el prefijo o el separador de bloque.';tr = 'Kodun seçilen kısmı, sonek, önek veya blok ayırıcı ile çakışmamalıdır.';it = 'Parte selezionata del codice dovrebbe non sovrapposizione con il suffisso, prefisso o separatore di blocco.';de = 'Der ausgewählte Teil des Codes sollte das Suffix, Präfix oder Blocktrennzeichen nicht überlappen.'"));
			Return;
		EndIf;
	EndIf;
	
	If Not IsBlankString(Suffix)
		AND Suffix = Right(DataRow, StrLen(Suffix)) Then
		DataRow = Left(DataRow, StrLen(DataRow)-StrLen(Suffix)); // cut suffix if any
		If CCol-1 > StrLen(DataRow) Then
			// Selected text overlaps the suffix.
			CommonClientServer.MessageToUser(NStr("en = 'Selected part of the code should not overlap the suffix, prefix or block separator.'; ru = 'Выделенный участок кода не должен пересекаться с суффиксом, префиксом или разделителем блоков.';pl = 'Wybrana część kodu nie powinna nakładać się na sufiks, przedrostek lub separator bloków.';es_ES = 'Parte seleccionada del código no tiene que superponerse al sufijo, el prefijo o el separador de bloque.';es_CO = 'Parte seleccionada del código no tiene que superponerse al sufijo, el prefijo o el separador de bloque.';tr = 'Kodun seçilen kısmı, sonek, önek veya blok ayırıcı ile çakışmamalıdır.';it = 'Parte selezionata del codice dovrebbe non sovrapposizione con il suffisso, prefisso o separatore di blocco.';de = 'Der ausgewählte Teil des Codes sollte das Suffix, Präfix oder Blocktrennzeichen nicht überlappen.'"));
			Return;
		EndIf;
	EndIf;
	
	SeparatorIsFound = Find(Mid(DataRow, NCol, CCol-NCol), Delimiter);
	If Not IsBlankString(Delimiter) AND SeparatorIsFound > 0 Then
		// Selected text crosses the delimiter.
		CommonClientServer.MessageToUser(NStr("en = 'Selected part of the code should not overlap the suffix, prefix or block separator.'; ru = 'Выделенный участок кода не должен пересекаться с суффиксом, префиксом или разделителем блоков.';pl = 'Wybrana część kodu nie powinna nakładać się na sufiks, przedrostek lub separator bloków.';es_ES = 'Parte seleccionada del código no tiene que superponerse al sufijo, el prefijo o el separador de bloque.';es_CO = 'Parte seleccionada del código no tiene que superponerse al sufijo, el prefijo o el separador de bloque.';tr = 'Kodun seçilen kısmı, sonek, önek veya blok ayırıcı ile çakışmamalıdır.';it = 'Parte selezionata del codice dovrebbe non sovrapposizione con il suffisso, prefisso o separatore di blocco.';de = 'Der ausgewählte Teil des Codes sollte das Suffix, Präfix oder Blocktrennzeichen nicht überlappen.'"));
		Return;
	EndIf;
	
	BlockNumber = 1;
	FirstFieldSymbolNumber = 1;
	FieldLenght = 1;
	
	While StrLen(DataRow) > 0 Do
		SeparatorPosition = Find(DataRow, Delimiter);
		If SeparatorPosition > NCol Then
			FirstFieldSymbolNumber = NCol;
			FieldLenght = ?(CCol > SeparatorPosition, SeparatorPosition - NCol, CCol - NCol);
			Break;
		EndIf;
		
		If SeparatorPosition = 0 OR IsBlankString(Delimiter) Then
			FirstFieldSymbolNumber = NCol;
			FieldLenght = CCol - NCol;
			Break;
		ElsIf SeparatorPosition = 1 Then
			// Selected text crosses the delimiter.
			CommonClientServer.MessageToUser(NStr("en = 'Selected part of the code should not overlap the suffix, prefix or block separator.'; ru = 'Выделенный участок кода не должен пересекаться с суффиксом, префиксом или разделителем блоков.';pl = 'Wybrana część kodu nie powinna nakładać się na sufiks, przedrostek lub separator bloków.';es_ES = 'Parte seleccionada del código no tiene que superponerse al sufijo, el prefijo o el separador de bloque.';es_CO = 'Parte seleccionada del código no tiene que superponerse al sufijo, el prefijo o el separador de bloque.';tr = 'Kodun seçilen kısmı, sonek, önek veya blok ayırıcı ile çakışmamalıdır.';it = 'Parte selezionata del codice dovrebbe non sovrapposizione con il suffisso, prefisso o separatore di blocco.';de = 'Der ausgewählte Teil des Codes sollte das Suffix, Präfix oder Blocktrennzeichen nicht überlappen.'"));
			Return;
		Else
			DataRow = Right(DataRow, StrLen(DataRow)-SeparatorPosition);
			NCol = NCol - SeparatorPosition;
			CCol = CCol - SeparatorPosition;
		EndIf;
		BlockNumber = BlockNumber + 1;
	EndDo;
	
	If CCol = StrLen(DataRow) + 1
		OR Mid(DataRow, CCol, 1) = Delimiter Then
		
		Result = New Structure("BlockNumber, FirstFieldSymbolNumber, FieldLenght", BlockNumber, FirstFieldSymbolNumber, FieldLenght);
		
		Context = New Structure;
		Context.Insert("NextAlert", Notification);
		Context.Insert("Result", Result);
		NextAlert = New NotifyDescription("DetermineFieldCoordinatesEnd", ThisObject, Context);
		
		ButtonList = New ValueList;
		ButtonList.Add(DialogReturnCode.Yes, NStr("en = 'Field length fixed'; ru = 'Длина поля фиксированная';pl = 'Stała długość pola';es_ES = 'Longitud del campo fijada';es_CO = 'Longitud del campo fijada';tr = 'Alan uzunluğu sabit';it = 'La lunghezza del campo è fissa';de = 'Feldlänge festgelegt'"));
		ButtonList.Add(DialogReturnCode.No, NStr("en = 'Field length is limited by the separator or by the row end'; ru = 'Длина поля ограничивается разделителем или концом строки';pl = 'Długość pola jest ograniczona przez separator lub koniec wiersza';es_ES = 'Longitud del campo está limitada por el separador o por el fin de la fila';es_CO = 'Longitud del campo está limitada por el separador o por el fin de la fila';tr = 'Alan uzunluğu ayırıcı veya satır sonu ile sınırlıdır';it = 'La lunghezza del campo è limitata dal separatore o dalla fine della linea';de = 'Die Feldlänge wird durch das Trennzeichen oder durch das Zeilenende begrenzt'"));
		ShowChooseFromMenu(NextAlert, ButtonList, );
		
	Else
		
		Result = New Structure("BlockNumber, FirstFieldSymbolNumber, FieldLenght", BlockNumber, FirstFieldSymbolNumber, FieldLenght);
		ExecuteNotifyProcessing(Notification, Result);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ControlOfFieldsUniqueness(Cancel)
	
	DoublesList = New Array;
	For y = 1 To 3 Do
		If Object["TrackAvailability"+String(y)] Then
			For Each curRow In Object["TrackFields"+String(y)] Do
				ControlOfFieldUniqueness(DoublesList, curRow.Field, curRow.LineNumber, "TrackFields"+String(y), Cancel);
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure ControlOfFieldUniqueness(DoublesList, Field, CurrentLineNumber, TableName, Cancel)
	If ValueIsFilled(Field) Then
		If DoublesList.Find(Field) = Undefined Then
			TwinCounter = 0;
			For G = 1 To 3 Do
				If Not Object["TrackAvailability"+String(G)] Then
					Continue;
				EndIf;
				
				For Each curField In Object["TrackFields"+String(G)] Do
					If curField.Field = Field Then
						TwinCounter = TwinCounter + 1;
						If TwinCounter > 1 Then
							StrMessage = NStr("en = 'Track %1, line %2: Field should be unique.'; ru = 'Дорожка %1, строка %2: Поле должно быть уникальным!';pl = 'Ciąg %1, wiersz %2: pole powinno być unikalne.';es_ES = 'Seguimiento %1, línea %2: Campo tiene que ser único.';es_CO = 'Seguimiento %1, línea %2: Campo tiene que ser único.';tr = 'Parça%1, satır%2: Alan benzersiz olmalı.';it = 'Traccia %1, riga %2: Il campo deve essere l''unico!';de = 'Track %1, Linie %2: Feld sollte eindeutig sein.'");
							StrMessage = StrReplace(StrMessage, "%1", Right("TrackFields"+String(G),1));
							StrMessage = StrReplace(StrMessage, "%2", String(curField.LineNumber));
							CommonClientServer.MessageToUser(StrMessage
								, ,"Object."+"TrackFields"+String(G)+"["+String(curField.LineNumber-1)+"].Field", , Cancel);
						EndIf;
					EndIf;
				EndDo;
			EndDo;
			If TwinCounter > 1 Then
				DoublesList.Add(Field);
			EndIf;
		EndIf;
		
	Else
		StrMessage = NStr("en = 'Track %1, line %2: Field cannot be empty.'; ru = 'Дорожка %1, строка %2: Поле не может быть пустым!';pl = 'Ciąg %1, wiersz %2: Pole nie może być puste.';es_ES = 'Seguimiento %1, línea %2: Campo no puede estar vacío.';es_CO = 'Seguimiento %1, línea %2: Campo no puede estar vacío.';tr = 'Parça%1, satır%2: Alan boş olamaz.';it = 'Traccia %1, riga %2: il campo non può essere vuoto!';de = 'Track %1, Linie %2: Feld darf nicht leer sein.'");
		StrMessage = StrReplace(StrMessage, "%1", Right(TableName,1));
		StrMessage = StrReplace(StrMessage, "%2", String(CurrentLineNumber));
		CommonClientServer.MessageToUser(StrMessage
			, ,"Object."+TableName+"["+String(CurrentLineNumber-1)+"].Field", , Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckTemplate()
	
	PatternData = New Structure(
		"TrackAvailability1, TrackAvailability2, TrackAvailability3, "
		+ "Prefix1, Prefix2, Prefix3, "
		+ "CodeLength1, CodeLength2, CodeLength3, "
		+ "Suffix1, Suffix2, Suffix3, "
		+ "BlocksDelimiter1, BlocksDelimiter2, BlocksDelimiter3, "
		+ "Ref",
		Object.TrackAvailability1, Object.TrackAvailability2, Object.TrackAvailability3
		,Object.Prefix1, Object.Prefix2, Object.Prefix3
		,Object.CodeLength1, Object.CodeLength2, Object.CodeLength3
		,Object.Suffix1, Object.Suffix2, Object.Suffix3
		,Object.BlocksDelimiter1, Object.BlocksDelimiter2, Object.BlocksDelimiter3
		,Object.Ref);
		
	OpenForm("Catalog.MagneticCardsTemplates.Form.TemplateCheckForm"
		, New Structure("PatternData", PatternData), ThisForm, ,,,, FormWindowOpeningMode.LockWholeInterface);      
	
EndProcedure

&AtClient
Procedure CheckTemplateEnd(Result, Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		If Not Write() Then
			CommonClientServer.MessageToUser(NStr("en = 'Cannot write the template'; ru = 'Не удалось записать шаблон';pl = 'Nie można zapisać szablonu';es_ES = 'No se puede inscribir el modelo';es_CO = 'No se puede inscribir el modelo';tr = 'Şablon yazılamıyor';it = 'Impossibile scrivere il modello';de = 'Kann die Vorlage nicht schreiben'"));
			Return;
		EndIf;
		
		CheckTemplate();
		
	EndIf;  
	
EndProcedure

&AtClient
Procedure CheckTemplateCommand(Command)
	
	// Check form on modification.
	// IN order the changes in template come into effect, you must save them.
	If Modified Then
		QuestionText = NStr("en = 'Template was changed. Save changes?'; ru = 'Шаблон был изменен, записать изменения?';pl = 'Szablon został zmieniony. Zapisać zmiany?';es_ES = 'Modelo se ha creado. ¿Guardar los cambios?';es_CO = 'Modelo se ha creado. ¿Guardar los cambios?';tr = 'Şablon değiştirildi. Değişiklikler kaydedilsin mi?';it = 'Il template è stato cambiato, registrare le modifiche?';de = 'Vorlage wurde geändert. Änderungen speichern?'");
		Notification = New NotifyDescription("CheckTemplateEnd", ThisObject);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
	Else
		CheckTemplate();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

// Sets the path field availability depending on the position of corresponding flag.
&AtClient
Procedure TrackAvailability1OnChange(Item)
	
	SetTracksEnabled();
	
EndProcedure

&AtClient
Procedure TrackAvailability2OnChange(Item)
	
	SetTracksEnabled();
	
EndProcedure

&AtClient
Procedure TrackAvailability3OnChange(Item)
	
	SetTracksEnabled();
	
EndProcedure

&AtClient
Procedure SetTracksEnabled()
	For y = 1 To 3 Do
		TrackAvailability = Object["TrackAvailability"+String(y)];
		Items["Prefix"+String(y)].Enabled 			= TrackAvailability;
		Items["CodeLength"+String(y)].Enabled 		= TrackAvailability;
		Items["Suffix"+String(y)].Enabled 			= TrackAvailability;
		Items["BlocksDelimiter"+String(y)].Enabled = TrackAvailability;
		Items["TrackFields"+String(y)].Enabled 		= TrackAvailability;
	EndDo;
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion
