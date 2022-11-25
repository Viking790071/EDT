////////////////////////////////////////////////////////////////////////////////
// Printing using templates in the OpenDocument Text (odt) format on the client. For backward compatibility.
//
// Description of the reference to a print form and a template.
// Structure containing fields:
// ServiceManager - service manager, Open Office service.
// Desktop - Open Office application (UNO service).
// Document - a document (print form).
// Type - a print form type ("ODT").
//
////////////////////////////////////////////////////////////////////////////////

#Region Private

// Print form initialization: a COM object is created and properties are set for it.
// 
Function InitializeOOWriterPrintForm(Val Template = Undefined) Export
	
	Try
		ServiceManager = New COMObject("com.sun.star.ServiceManager");
	Except
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			NStr("ru = 'Ошибка при связи с сервис менеджером (com.sun.star.ServiceManager).'; en = 'An error occurred when connecting to the service manager (com.sun.star.ServiceManager).'; pl = 'Podczas połączenia z menedżerem serwisu wystąpił błąd (com.sun.star.ServiceManager).';es_ES = 'Ha ocurrido un error al contactar el gestor de servicio (com.sun.star.ServiceManager).';es_CO = 'Ha ocurrido un error al contactar el gestor de servicio (com.sun.star.ServiceManager).';tr = 'Servis yöneticisiyle iletişim kurarken bir hata oluştu (com.sun.star.ServiceManager).';it = 'Si è verificato un errore durante la connessione al gestore di servizi (com.sun.star.ServiceManager).';de = 'Beim Kontaktieren mit dem Service-Managers (com.sun.star.ServiceManager) ist ein Fehler aufgetreten.'")
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Try
		Desktop = ServiceManager.CreateInstance("com.sun.star.frame.Desktop");
	Except
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			NStr("ru = 'Ошибка при запуске сервиса Desktop (com.sun.star.frame.Desktop).'; en = 'An error occurred when starting Desktop service (com.sun.star.frame.Desktop).'; pl = 'Podczas uruchamiania serwisu Desktop wystąpił błąd (com.sun.star.frame.Desktop).';es_ES = 'Ha ocurrido un error al lanzar el servicio de Escritorio (com.sun.star.frame.Desktop).';es_CO = 'Ha ocurrido un error al lanzar el servicio de Escritorio (com.sun.star.frame.Desktop).';tr = 'Masaüstü hizmetini başlatırken bir hata oluştu (com.sun.star.frame.Desktop).';it = 'Errore durante l''avvio del servizio Desktop (com.sun.star.frame.Desktop).';de = 'Beim Starten des Desktop-Services (com.sun.star.frame.Desktop) ist ein Fehler aufgetreten.'")
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Parameters = GetComSafeArray();
	
#If Not WebClient Then
	Parameters.SetValue(0, PropertyValue(ServiceManager, "Hidden", True));
#EndIf
	
	Document = Desktop.LoadComponentFromURL("private:factory/swriter", "_blank", 0, Parameters);
	
#If WebClient Then
	Document.getCurrentController().getFrame().getContainerWindow().setVisible(False);
#EndIf
	
	// Customizing fields by a template.
	If Template <> Undefined Then
		TemplateStyleName = Template.Document.CurrentController.getViewCursor().PageStyleName;
		TemplateStyle = Template.Document.StyleFamilies.getByName("PageStyles").getByName(TemplateStyleName);
			
		StyleName = Document.CurrentController.getViewCursor().PageStyleName;
		Style = Document.StyleFamilies.getByName("PageStyles").getByName(StyleName);
		
		Style.TopMargin = TemplateStyle.TopMargin;
		Style.LeftMargin = TemplateStyle.LeftMargin;
		Style.RightMargin = TemplateStyle.RightMargin;
		Style.BottomMargin = TemplateStyle.BottomMargin;
	EndIf;
	
	// Preparing a template reference.
	Handler = New Structure("ServiceManager,Desktop,Document,Type");
	Handler.ServiceManager = ServiceManager;
	Handler.Desktop = Desktop;
	Handler.Document = Document;
	
	Return Handler;
	
EndFunction

// Returns a structure with a print form template.
//
// Parameters:
// BinaryTemplateData - BinaryData - binary data of a template.
// Returns:
// structure - a template reference.
//
Function GetOOWriterTemplate(Val BinaryTemplateData, TempFileName) Export
	
	Handler = New Structure("ServiceManager,Desktop,Document,FileName");
	
	Try
		ServiceManager = New COMObject("com.sun.star.ServiceManager");
	Except
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			NStr("ru = 'Ошибка при связи с сервис менеджером (com.sun.star.ServiceManager).'; en = 'An error occurred when connecting to the service manager (com.sun.star.ServiceManager).'; pl = 'Podczas połączenia z menedżerem serwisu wystąpił błąd (com.sun.star.ServiceManager).';es_ES = 'Ha ocurrido un error al contactar el gestor de servicio (com.sun.star.ServiceManager).';es_CO = 'Ha ocurrido un error al contactar el gestor de servicio (com.sun.star.ServiceManager).';tr = 'Servis yöneticisiyle iletişim kurarken bir hata oluştu (com.sun.star.ServiceManager).';it = 'Si è verificato un errore durante la connessione al gestore di servizi (com.sun.star.ServiceManager).';de = 'Beim Kontaktieren mit dem Service-Managers (com.sun.star.ServiceManager) ist ein Fehler aufgetreten.'")
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Try
		Desktop = ServiceManager.CreateInstance("com.sun.star.frame.Desktop");
	Except
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			NStr("ru = 'Ошибка при запуске сервиса Desktop (com.sun.star.frame.Desktop).'; en = 'An error occurred when starting Desktop service (com.sun.star.frame.Desktop).'; pl = 'Podczas uruchamiania serwisu Desktop wystąpił błąd (com.sun.star.frame.Desktop).';es_ES = 'Ha ocurrido un error al lanzar el servicio de Escritorio (com.sun.star.frame.Desktop).';es_CO = 'Ha ocurrido un error al lanzar el servicio de Escritorio (com.sun.star.frame.Desktop).';tr = 'Masaüstü hizmetini başlatırken bir hata oluştu (com.sun.star.frame.Desktop).';it = 'Errore durante l''avvio del servizio Desktop (com.sun.star.frame.Desktop).';de = 'Beim Starten des Desktop-Services (com.sun.star.frame.Desktop) ist ein Fehler aufgetreten.'")
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
#If WebClient Then
	FilesDetails = New Array;
	FilesDetails.Add(New TransferableFileDescription(TempFileName, PutToTempStorage(BinaryTemplateData)));
	TemporaryDirectory = PrintManagementInternalClient.CreateTemporaryDirectory("OOWriter");
	If NOT GetFiles(FilesDetails, , TemporaryDirectory, False) Then
		Return Undefined;
	EndIf;
	TempFileName = CommonClientServer.AddLastPathSeparator(TemporaryDirectory) + TempFileName;
#Else
	TempFileName = GetTempFileName("ODT");
	BinaryTemplateData.Write(TempFileName);
#EndIf
	
	DocumentParameters = GetComSafeArray();
#If Not WebClient Then
	DocumentParameters.SetValue(0, PropertyValue(ServiceManager, "Hidden", True));
#EndIf
	
	// Opening parameters: disabling macros.
	RunMode = PropertyValue(ServiceManager,
		"MacroExecutionMode",
		0); // const short NEVER_EXECUTE = 0
	DocumentParameters.SetValue(0, RunMode);
	
	Document = Desktop.LoadComponentFromURL("file:///" + StrReplace(TempFileName, "\", "/"), "_blank", 0, DocumentParameters);
	
#If WebClient Then
	Document.getCurrentController().getFrame().getContainerWindow().setVisible(False);
#EndIf
	
	// Preparing a template reference.
	Handler.ServiceManager = ServiceManager;
	Handler.Desktop = Desktop;
	Handler.Document = Document;
	Handler.FileName = TempFileName;
	
	Return Handler;
	
EndFunction

// Closes a print form template and deletes references to the COM object.
//
Function CloseConnection(Handler, Val CloseApplication) Export
	
	If CloseApplication Then
		Handler.Document.Close(0);
	EndIf;
	
	Handler.Document = Undefined;
	Handler.Desktop = Undefined;
	Handler.ServiceManager = Undefined;
	ScriptControl = Undefined;
	
	If Handler.Property("FileName") Then
		DeleteFiles(Handler.FileName);
	EndIf;
	
	Handler = Undefined;
	
EndFunction

// Sets a visibility property for OO Writer application.
// Handler - a reference to a print form.
//
Procedure ShowOOWriterDocument(Val Handler) Export
	
	ContainerWindow = Handler.Document.getCurrentController().getFrame().getContainerWindow();
	ContainerWindow.setVisible(True);
	ContainerWindow.setFocus();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Template operations

// Gets an area from the template.
// Parameters:
// Handler - a reference to a template
// AreaName - an area name in the template.
// OffsetStart - offset from the area start, default offset: 1 - the area is taken without a newline 
//					character, after the operator parenthesis of the area opening.
//					
// OffsetEnd - offset from the area end, default offset:- 11 - the area is taken without a newline 
//					character, before the operator parenthesis of the area closing.
//					
//
Function GetTemplateArea(Val Handler, Val AreaName) Export
	
	Result = New Structure("Document,Start,End");
	
	Result.Start = GetAreaStartPosition(Handler.Document, AreaName);
	Result.End   = GetAreaEndPosition(Handler.Document, AreaName);
	Result.Document = Handler.Document;
	
	Return Result;
	
EndFunction

// Gets a header area.
//
Function GetHeaderArea(Val TemplateRef) Export
	
	Return New Structure("Document, ServiceManager", TemplateRef.Document, TemplateRef.ServiceManager);
	
EndFunction

// Gets a footer area.
//
Function GetFooterArea(TemplateRef) Export
	
	Return New Structure("Document, ServiceManager", TemplateRef.Document, TemplateRef.ServiceManager);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Print form operations

// Inserts a line break to the next row.
// Parameters:
// Handler - a reference to a Microsoft Word document. A line break is to be added to this document.
//
Procedure InsertBreakAtNewLine(Val Handler) Export
	
	oText = Handler.Document.getText();
	oCursor = oText.createTextCursor();
	oCursor.gotoEnd(False);
	oText.insertControlCharacter(oCursor, 0, False);
	
EndProcedure

// Adds a header to a print form.
//
Procedure AddHeader(Val PrintForm,
									Val Area) Export
	
	Template_oTxtCrsr = SetMainCursorToHeader(Area);
	While Template_oTxtCrsr.goRight(1, True) Do
	EndDo;
	TransferableObject = Area.Document.getCurrentController().Frame.controller.getTransferable();
	
	SetMainCursorToHeader(PrintForm);
	PrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
EndProcedure

// Adds a footer to a print form.
//
Procedure AddFooter(Val PrintForm,
									Val Area) Export
	
	Template_oTxtCrsr = SetMainCursorToFooter(Area);
	While Template_oTxtCrsr.goRight(1, True) Do
	EndDo;
	TransferableObject = Area.Document.getCurrentController().Frame.controller.getTransferable();
	
	SetMainCursorToFooter(PrintForm);
	PrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
EndProcedure

// Adds an area from a template to a print form, replacing the area parameters with the object data 
// values.
// The procedure is used upon output of a single area.
//
// Parameters:
// PrintForm - a reference to a print form.
// AreaHandler - a reference to an area in the template.
// GoToNextRow - boolean, shows if it is required to add a line break after the area output.
//
// Returns:
// AreaCoordinates
//
Procedure AttachArea(Val HandlerPrintForm,
							Val HandlerArea,
							Val GoToNextRow = True,
							Val JoinTableRow = False) Export
	
	Template_oTxtCrsr = HandlerArea.Document.getCurrentController().getViewCursor();
	Template_oTxtCrsr.gotoRange(HandlerArea.Start, False);
	
	If NOT JoinTableRow Then
		Template_oTxtCrsr.goRight(1, False);
	EndIf;
	
	Template_oTxtCrsr.gotoRange(HandlerArea.End, True);
	
	TransferableObject = HandlerArea.Document.getCurrentController().Frame.controller.getTransferable();
	HandlerPrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
	If JoinTableRow Then
		DeleteRow(HandlerPrintForm);
	EndIf;
	
	If GoToNextRow Then
		InsertBreakAtNewLine(HandlerPrintForm);
	EndIf;
	
EndProcedure

// Fills parameters in a print form tabular section.
//
Procedure FillParameters(PrintForm, Data) Export
	
	For Each KeyValue In Data Do
		If TypeOf(KeyValue) <> Type("Array") Then
			ReplacementString = KeyValue.Value;
			If IsTempStorageURL(ReplacementString) Then
#If WebClient Then
				TempFileName = TempFilesDir() + String(New UUID) + ".tmp";
#Else
				TempFileName = GetTempFileName("tmp");
#EndIf
				BinaryData = GetFromTempStorage(ReplacementString);
				BinaryData.Write(TempFileName);
				
				TextGraphicObject = PrintForm.Document.createInstance("com.sun.star.text.TextGraphicObject");
				FileURL = FileNameInURL(TempFileName);
				TextGraphicObject.GraphicURL = FileURL;
				
				Document = PrintForm.Document;
				SearchDescriptor = Document.CreateSearchDescriptor();
				SearchDescriptor.SearchString = "{v8 " + KeyValue.Key + "}";
				SearchDescriptor.SearchCaseSensitive = False;
				SearchDescriptor.SearchWords = False;
				Found = Document.FindFirst(SearchDescriptor);
				While Found <> Undefined Do
					Found.GetText().InsertTextContent(Found.getText(), TextGraphicObject, True);
					Found = Document.FindNext(Found.End, SearchDescriptor);
				EndDo;
			Else
				PF_oDoc = PrintForm.Document;
				PF_ReplaceDescriptor = PF_oDoc.createReplaceDescriptor();
				PF_ReplaceDescriptor.SearchString = "{v8 " + KeyValue.Key + "}";
				PF_ReplaceDescriptor.ReplaceString = String(KeyValue.Value);
				PF_oDoc.replaceAll(PF_ReplaceDescriptor);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Adds a collection area to a print form.
//
Procedure JoinAndFillCollection(Val HandlerPrintForm,
										  Val HandlerArea,
										  Val Data,
										  Val IsTableRow = False,
										  Val GoToNextRow = True) Export
	
	Template_oTxtCrsr = HandlerArea.Document.getCurrentController().getViewCursor();
	Template_oTxtCrsr.gotoRange(HandlerArea.Start, False);
	
	If NOT IsTableRow Then
		Template_oTxtCrsr.goRight(1, False);
	EndIf;
	Template_oTxtCrsr.gotoRange(HandlerArea.End, True);
	
	TransferableObject = HandlerArea.Document.getCurrentController().Frame.controller.getTransferable();
	
	For Each RowWithData In Data Do
		HandlerPrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
		If IsTableRow Then
			DeleteRow(HandlerPrintForm);
		EndIf;
		FillParameters(HandlerPrintForm, RowWithData);
	EndDo;
	
	If GoToNextRow Then
		InsertBreakAtNewLine(HandlerPrintForm);
	EndIf;
	
EndProcedure

// Sets a mouse pointer to the end of the DocumentRef document.
//
Procedure SetMainCursorToDocumentBody(Val DocumentRef) Export
	
	oDoc = DocumentRef.Document;
	oViewCursor = oDoc.getCurrentController().getViewCursor();
	oTextCursor = oDoc.Text.createTextCursor();
	oViewCursor.gotoRange(oTextCursor, False);
	oViewCursor.gotoEnd(False);
	
EndProcedure

// Sets a mouse pointer to the header.
//
Function SetMainCursorToHeader(Val DocumentRef) Export
	
	xCursor = DocumentRef.Document.getCurrentController().getViewCursor();
	PageStyleName = xCursor.getPropertyValue("PageStyleName");
	oPStyle = DocumentRef.Document.getStyleFamilies().getByName("PageStyles").getByName(PageStyleName);
	oPStyle.HeaderIsOn = True;
	HeaderTextCursor = oPStyle.getPropertyValue("HeaderText").createTextCursor();
	xCursor.gotoRange(HeaderTextCursor, False);
	Return xCursor;
	
EndFunction

// Sets a mouse pointer to the footer.
//
Function SetMainCursorToFooter(Val DocumentRef) Export
	
	xCursor = DocumentRef.Document.getCurrentController().getViewCursor();
	PageStyleName = xCursor.getPropertyValue("PageStyleName");
	oPStyle = DocumentRef.Document.getStyleFamilies().getByName("PageStyles").getByName(PageStyleName);
	oPStyle.FooterIsOn = True;
	FooterTextCursor = oPStyle.getPropertyValue("FooterText").createTextCursor();
	xCursor.gotoRange(FooterTextCursor, False);
	Return xCursor;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

// Gets a structure used to set UNO object parameters.
// 
//
Function PropertyValue(Val ServiceManager, Val Property, Val Value)
	
	PropertyValue = ServiceManager.Bridge_GetStruct("com.sun.star.beans.PropertyValue");
	PropertyValue.Name = Property;
	PropertyValue.Value = Value;
	
	Return PropertyValue;
	
EndFunction

Function GetAreaStartPosition(Val xDocument, Val AreaName)
	
	TextToSearch = "{v8 Area." + AreaName + "}";
	
	xSearchDescr = xDocument.createSearchDescriptor();
	xSearchDescr.SearchString = TextToSearch;
	xSearchDescr.SearchCaseSensitive = False;
	xSearchDescr.SearchWords = True;
	xFound = xDocument.findFirst(xSearchDescr);
	If xFound = Undefined Then
		Raise NStr("ru = 'Не найдено начало области макета:'; en = 'Area template beginning is not found:'; pl = 'Nie znaleziono początku obszaru szablonu:';es_ES = 'Inicio del área del modelo no encontrado:';es_CO = 'Inicio del área del modelo no encontrado:';tr = 'Şablon alanı başlangıcı bulunamadı:';it = 'L''inizio dell''area modello non trovato:';de = 'Start des Vorlagenbereichs wurde nicht gefunden:'") + " " + AreaName;	
	EndIf;
	Return xFound.End;
	
EndFunction

Function GetAreaEndPosition(Val xDocument, Val AreaName)
	
	TextToSearch = "{/v8 Area." + AreaName + "}";
	
	xSearchDescr = xDocument.createSearchDescriptor();
	xSearchDescr.SearchString = TextToSearch;
	xSearchDescr.SearchCaseSensitive = False;
	xSearchDescr.SearchWords = True;
	xFound = xDocument.findFirst(xSearchDescr);
	If xFound = Undefined Then
		Raise NStr("ru = 'Не найден конец области макета:'; en = 'Area template end is not found:'; pl = 'Nie znaleziono końca obszaru szablonu:';es_ES = 'Fin del área del modelo no encontrado:';es_CO = 'Fin del área del modelo no encontrado:';tr = 'Şablon alanının sonu bulunamadı:';it = 'L''area template finale non è stata trovata:';de = 'Ende des Vorlagenbereichs wurde nicht gefunden:'") + " " + AreaName;	
	EndIf;
	Return xFound.Start;
	
EndFunction

Procedure DeleteRow(HandlerPrintForm)
	
	oFrame = HandlerPrintForm.Document.getCurrentController().Frame;
	
	dispatcher = HandlerPrintForm.ServiceManager.CreateInstance ("com.sun.star.frame.DispatchHelper");
	
	oViewCursor = HandlerPrintForm.Document.getCurrentController().getViewCursor();
	
	dispatcher.executeDispatch(oFrame, ".uno:GoUp", "", 0, GetComSafeArray());
	
	While oViewCursor.TextTable <> Undefined Do
		dispatcher.executeDispatch(oFrame, ".uno:GoUp", "", 0, GetComSafeArray());
	EndDo;
	
	dispatcher.executeDispatch(oFrame, ".uno:Delete", "", 0, GetComSafeArray());
	
	While oViewCursor.TextTable <> Undefined Do
		dispatcher.executeDispatch(oFrame, ".uno:GoDown", "", 0, GetComSafeArray());
	EndDo;
	
EndProcedure

Function GetComSafeArray()
	
#If WebClient Then
	scr = New COMObject("MSScriptControl.ScriptControl");
	scr.language = "javascript";
	scr.eval("Array=new Array()");
	Return scr.eval("Array");
#Else
	Return New COMSafeArray("VT_DISPATCH", 1);
#EndIf
	
EndFunction

Function EventLogEvent()
	Return NStr("ru = 'Печать'; en = 'Print'; pl = 'Drukuj';es_ES = 'Impresión';es_CO = 'Impresión';tr = 'Yazdır';it = 'Stampa';de = 'Drucken'");
EndFunction

Procedure FailedToGeneratePrintForm(ErrorInformation)
#If WebClient Then
	ClarificationText = Chars.LF + NStr("ru = 'Для формирования этой печатной формы необходимо воспользоваться тонким клиентом.'; en = 'Use a thin client to generate this print from.'; pl = 'Do tworzenia formularzy wydruku, należy skorzystać z cienkiego klienta.';es_ES = 'Para generar este formulario de impresión es necesario usar el cliente ligero.';es_CO = 'Para generar este formulario de impresión es necesario usar el cliente ligero.';tr = 'Bu baskı formunu oluşturmak için ince istemci kullanmanız gerekir.';it = 'Utilizza un thin client per generare questo modulo di stampa.';de = 'Um diese Druckform zu generieren, benötigen Sie einen Thin Client.'");
#Else		
	ClarificationText = "";	
#EndIf
	ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Для вывода печатных форм в формате OpenOffice.org Writer требуется, чтобы на компьютере был установлен пакет OpenOffice.org. %1
		|Технические подробности: %2'; 
		|en = 'To display print forms in the OpenOffice.org Writer format, install OpenOffice.org package on your computer. %1
		|Technical details: %2'; 
		|pl = 'Dla wyprowadzenia formularzy wydruku w formacie OpenOffice.org Writer jest wymagane, aby na komputerze był zainstalowany pakiet OpenOffice.org. %1
		|Szczegóły techniczne: %2';
		|es_ES = 'Para ver los formularios de impresión en el formato OpenOffice.org Writer se requiere que en el ordenador esté instalado OpenOffice.org.%1
		|Detalles técnicos: %2';
		|es_CO = 'Para ver los formularios de impresión en el formato OpenOffice.org Writer se requiere que en el ordenador esté instalado OpenOffice.org.%1
		|Detalles técnicos: %2';
		|tr = 'Yazdırılan form çıktı biçimi için OpenOffice.org Writer, paketin bilgisayarda yüklenmesini gerektirir OpenOffice.org-evet. %1
		|Teknik detaylar:%2';
		|it = 'Per l''anteprima dei moduli di stampa in OpenOffice.org Writer, installare il pacchetto OpenOffice.org sul computer. %1
		|Dettagli tecnici: %2';
		|de = 'Um gedruckte Formulare im OpenOffice.org Writer-Format auszugeben, müssen Sie OpenOffice.org auf Ihrem Computer installiert haben. %1
		|Technische Details: %2'"),
		ClarificationText, BriefErrorDescription(ErrorInformation));
	Raise ExceptionText;
EndProcedure

Function FileNameInURL(Val FileName)
	FileName = StrReplace(FileName, " ", "%20");
	FileName = StrReplace(FileName, "\", "/"); 
	Return "file:/" + "/localhost/" + FileName; 
EndFunction

#EndRegion