// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	CashCR = Settings.Get("CashCR");
	CurrentSessionOnly = Settings.Get("CurrentSessionOnly");
	
	UpdateCashCRSessionStateAtServer(CashCR);
	SetDynamicListsFilter();
	
	Items.CashDeposition.Visible = Not CashCR.UseWithoutEquipmentConnection;
	Items.Withdrawal.Visible = Not CashCR.UseWithoutEquipmentConnection;
	
EndProcedure

#Region ProcedureFormFieldEventHandlers

// Procedure sets filter of dynamic form lists.
//
&AtServer
Procedure SetDynamicListsFilter()
	
	DriveClientServer.SetListFilterItem(SalesSlips, "CashCR", CashCR, ValueIsFilled(CashCR), DataCompositionComparisonType.Equal);
	DriveClientServer.SetListFilterItem(SalesSlips, "CashCRSession", CurrentCashCRSession, CurrentSessionOnly, DataCompositionComparisonType.Equal);
	
EndProcedure

// Procedure - event handler "OnChange" of field "CashCR".
//
&AtServer
Procedure CashCRFilterOnChangeAtServer()
	
	UpdateCashCRSessionStateAtServer(CashCR);
	SetDynamicListsFilter();
	Items.CashDeposition.Visible = Not CashCR.UseWithoutEquipmentConnection;
	Items.Withdrawal.Visible = Not CashCR.UseWithoutEquipmentConnection;
	
EndProcedure

// Procedure - event handler "OnChange" of field "CashCR" on server.
//
&AtClient
Procedure CashCRFilterOnChange(Item)
	
	CashCRFilterOnChangeAtServer();
	
EndProcedure

// Function opens the cash session on server.
//
&AtServer
Function CashCRSessionOpenAtServer(CashCR, ErrorDescription = "")
	
	Return Documents.ShiftClosure.CashCRSessionOpen(CashCR, ErrorDescription);
	
EndFunction

// Procedure closes the cash session on server.
//
&AtServer
Function CloseCashCRSessionAtServer(CashCR, ErrorDescription = "")
	
	Return Documents.ShiftClosure.CloseCashCRSessionExecuteArchiving(CashCR, ErrorDescription);
	
EndFunction

// It is required to call the procedure from client when opening the cash session
&AtServer
Procedure UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR)
	
	UpdateCashCRSessionStateAtServer(CashCR);
	
	SetDynamicListsFilter();
	
EndProcedure

// Procedure - command handler "OpenCashCRSession".
//
&AtClient
Procedure CashCRSessionOpen(Command)
	
	ClearMessages();
	
	If Not ValueIsFilled(CashCR) Then
		Return;
	EndIf;
	
	Result = False;
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If DeviceIdentifier <> Undefined OR UseWithoutEquipmentConnection Then
			
			ErrorDescription = "";
			
			If Not UseWithoutEquipmentConnection Then
				
				Result = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifier,
					ErrorDescription
				);
				
			EndIf;
			
			If Result OR UseWithoutEquipmentConnection Then
				
				If Not UseWithoutEquipmentConnection Then
					
					InputParameters   = Undefined;
					Output_Parameters = Undefined;
					
					// Open session on fiscal register
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifier,
						"OpenDay",
						InputParameters, 
						Output_Parameters
					);
					
				EndIf;
				
				If Result OR UseWithoutEquipmentConnection Then
					
					Result = CashCRSessionOpenAtServer(CashCR, ErrorDescription);
					
					If Not Result Then
						
						MessageText = NStr("en = 'An error occurred when opening the session.
						                   |Session is not opened.
						                   |Additional
						                   |description: %AdditionalDetails%'; 
						                   |ru = 'При открытии смены произошла ошибка.
						                   |Смена не открыта.
						                   |Дополнительное
						                   |описание: %AdditionalDetails%';
						                   |pl = 'W czasie otwierania sesji wystąpił błąd.
						                   |Sesja nie została otwarta.
						                   |Dodatkowy
						                   |opis: %AdditionalDetails%';
						                   |es_ES = 'Ha ocurrido un error al abrir la sesión.
						                   |Sesión no está abierta.
						                   |Descripción
						                   |adicional: %AdditionalDetails%';
						                   |es_CO = 'Ha ocurrido un error al abrir la sesión.
						                   |Sesión no está abierta.
						                   |Descripción
						                   |adicional: %AdditionalDetails%';
						                   |tr = 'Oturum açıldığında bir hata oluştu. 
						                   |Oturum açılmadı. 
						                   |Ek 
						                   |açıklama:%AdditionalDetails%';
						                   |it = 'Si è verificato un errore all''avvio della sessione. 
						                   |La sessione non è avviata.
						                   |Descrizione
						                   |aggiuntiva: %AdditionalDetails%';
						                   |de = 'Beim Öffnen der Sitzung ist ein Fehler aufgetreten.
						                   |Sitzung ist nicht geöffnet.
						                   |Zusätzliche
						                   |Beschreibung: %AdditionalDetails%'");
						MessageText = StrReplace(MessageText,"%AdditionalDetails%",
							?(UseWithoutEquipmentConnection, ErrorDescription, Output_Parameters[1]));
						CommonClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en = 'An error occurred when opening the session.
					                   |Session is not opened.
					                   |Additional
					                   |description: %AdditionalDetails%'; 
					                   |ru = 'При открытии смены произошла ошибка.
					                   |Смена не открыта.
					                   |Дополнительное
					                   |описание: %AdditionalDetails%';
					                   |pl = 'W czasie otwierania sesji wystąpił błąd.
					                   |Sesja nie została otwarta.
					                   |Dodatkowy
					                   |opis: %AdditionalDetails%';
					                   |es_ES = 'Ha ocurrido un error al abrir la sesión.
					                   |Sesión no está abierta.
					                   |Descripción
					                   |adicional: %AdditionalDetails%';
					                   |es_CO = 'Ha ocurrido un error al abrir la sesión.
					                   |Sesión no está abierta.
					                   |Descripción
					                   |adicional: %AdditionalDetails%';
					                   |tr = 'Oturum açıldığında bir hata oluştu. 
					                   |Oturum açılmadı. 
					                   |Ek 
					                   |açıklama:%AdditionalDetails%';
					                   |it = 'Si è verificato un errore all''avvio della sessione. 
					                   |La sessione non è avviata.
					                   |Descrizione
					                   |aggiuntiva: %AdditionalDetails%';
					                   |de = 'Beim Öffnen der Sitzung ist ein Fehler aufgetreten.
					                   |Sitzung ist nicht geöffnet.
					                   |Zusätzliche
					                   |Beschreibung: %AdditionalDetails%'");
					MessageText = StrReplace(MessageText,"%AdditionalDetails%",ErrorDescription);
					CommonClientServer.MessageToUser(MessageText);
					
				EndIf;
				
				If Not UseWithoutEquipmentConnection Then
					
					EquipmentManagerClient.DisableEquipmentById(
						UUID,
						DeviceIdentifier
					);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Session is not opened on the fiscal register.
				                   |Additional
				                   |description: %AdditionalDetails%'; 
				                   |ru = 'При подключении устройства произошла ошибка.
				                   |Смена не открыта на фискальном регистраторе.
				                   |Дополнительное
				                   |описание: %AdditionalDetails%';
				                   |pl = 'Podczas podłączania urządzenia wystąpił błąd.
				                   |Sesja nie została otwarta w rejestratorze fiskalnym.
				                   |Dodatkowy
				                   | opis: %AdditionalDetails%';
				                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Sesión no está abierta en el registro fiscal.
				                   |Descripción
				                   |adicional:%AdditionalDetails%';
				                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Sesión no está abierta en el registro fiscal.
				                   |Descripción
				                   |adicional:%AdditionalDetails%';
				                   |tr = 'Cihaz bağlanırken hata oluştu.
				                   |Mali kayıtta oturum açılmadı.
				                   |Ek
				                   | açıklama: %AdditionalDetails%';
				                   |it = 'Si è verificato un errore durante il collegamento del dispositivo.
				                   |La sessione non viene aperta sul registro fiscale.
				                   |Descrizione
				                   |Aggiuntiva: %AdditionalDetails%';
				                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
				                   |Sitzung ist nicht im Fiskalspeicher geöffnet.
				                   |Zusätzliche
				                   |Beschreibung: %AdditionalDetails%'");
				MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'"
		);
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
	
EndProcedure

// Function verifies the existence of issued receipts during the session.
//
&AtServer
Function IssuedReceiptsExist(CashCR)
	
	StructureStateCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	
	If StructureStateCashCRSession.CashCRSessionStatus <> Enums.ShiftClosureStatus.IsOpen Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	SalesSlipInventory.Ref AS CountRecipies
	|FROM
	|	(SELECT
	|		SalesSlipInventory.Ref AS Ref
	|	FROM
	|		Document.SalesSlip.Inventory AS SalesSlipInventory
	|	WHERE
	|		SalesSlipInventory.Ref.CashCRSession = &CashCRSession
	|		AND SalesSlipInventory.Ref.Posted
	|		AND SalesSlipInventory.Ref.SalesSlipNumber > 0
	|		AND (NOT SalesSlipInventory.Ref.Archival)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SalesSlipInventory.Ref
	|	FROM
	|		Document.ProductReturn.Inventory AS SalesSlipInventory
	|	WHERE
	|		SalesSlipInventory.Ref.CashCRSession = &CashCRSession
	|		AND SalesSlipInventory.Ref.Posted
	|		AND SalesSlipInventory.Ref.SalesSlipNumber > 0
	|		AND (NOT SalesSlipInventory.Ref.Archival)) AS SalesSlipInventory";
	
	Query.SetParameter("CashCRSession", StructureStateCashCRSession.CashCRSession);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Procedure - command handler "CloseCashCRSession".
//
&AtClient
Procedure CloseCashCRSession(Command)
	
	ClearMessages();
	
	If Not ValueIsFilled(CashCR) Then
		Return;
	EndIf;
	
	Result = False;
	
	If Not IssuedReceiptsExist(CashCR) Then
		
		ErrorDescription = "";
		
		DocumentArray = CloseCashCRSessionAtServer(CashCR, ErrorDescription);
		
		If ValueIsFilled(ErrorDescription) Then
			MessageText = NStr("en = 'Session is closed on the fiscal register, but errors occurred when generating the retail sales report.
			                   |Additional
			                   |description: %AdditionalDetails%'; 
			                   |ru = 'Смена закрыта на фискальном регистраторе, но при формировании отчета о розничных продажах возникли ошибки.
			                   |Дополнительное
			                   |описание: %AdditionalDetails%';
			                   |pl = 'Sesja została zamknięta w rejestratorze fiskalnym, ale podczas tworzenia raportu o sprzedaży detalicznej wystąpiły błędy.
			                   |Dodatkowy
			                   |opis: %AdditionalDetails%';
			                   |es_ES = 'Sesión está cerrada en el registro fiscal pero han ocurrido errores al generar el informe de ventas minoristas.
			                   |Descripción
			                   |adicional: %AdditionalDetails%';
			                   |es_CO = 'Sesión está cerrada en el registro fiscal pero han ocurrido errores al generar el informe de ventas minoristas.
			                   |Descripción
			                   |adicional: %AdditionalDetails%';
			                   |tr = 'Mali kayıtta oturum kapatıldı, ancak perakende satış raporu oluşturulurken hatalar oluştu.
			                   |Ek
			                   |açıklama: %AdditionalDetails%';
			                   |it = 'La sessione è chiusa sul registratore fiscale, ma errori si sono registrati durante la generazione del report di vendite al dettaglio.
			                   |Descrizione
			                   |aggiuntiva: %AdditionalDetails%';
			                   |de = 'Die Sitzung wird im Fiskalspeicher geschlossen, es sind jedoch Fehler beim Generieren des Einzelhandelsumsatzberichts aufgetreten.
			                   |Zusätzliche
			                   |Beschreibung: %AdditionalDetails%'");
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
		// Show all resulting documents to user.
		For Each Document In DocumentArray Do
			
			OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key", Document));
			
		EndDo;
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
	
		If DeviceIdentifier <> Undefined OR UseWithoutEquipmentConnection Then
			
			ErrorDescription = "";
			
			If Not UseWithoutEquipmentConnection Then
				
				Result = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifier,
					ErrorDescription
				);
				
			EndIf;
			
			If Result OR UseWithoutEquipmentConnection Then
				
				If Not UseWithoutEquipmentConnection Then
					InputParameters  = Undefined;
					Output_Parameters = Undefined;
					
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifier,
						"PrintZReport",
						InputParameters,
						Output_Parameters
					);
				EndIf;
				
				If Not Result AND Not UseWithoutEquipmentConnection Then
					
					MessageText = NStr("en = 'Error occurred when closing the session on the fiscal register.
					                   |""%ErrorDescription%""
					                   |Report on fiscal register is not formed.'; 
					                   |ru = 'При закрытии смены на фискальном регистраторе произошла ошибка.
					                   |""%ErrorDescription%""
					                   |Отчет на фискальном регистраторе не сформирован.';
					                   |pl = 'Wystąpił błąd podczas zamykania sesji w rejestratorze fiskalnym.
					                   |""%ErrorDescription%""
					                   |Raport na rejestratorze fiskalnym nie był utworzony.';
					                   |es_ES = 'Ha ocurrido un error al cerrar la sesión en el registro fiscal.
					                   |""%ErrorDescription%""
					                   |Informe en el registro fiscal no se ha formado.';
					                   |es_CO = 'Ha ocurrido un error al cerrar la sesión en el registro fiscal.
					                   |""%ErrorDescription%""
					                   |Informe en el registro fiscal no se ha formado.';
					                   |tr = 'Mali kaydedicide oturum kapatılırken bir hata oluştu
					                   | ""%ErrorDescription%""
					                   |Mali kayıtla ilgili rapor oluşturulmadı.';
					                   |it = 'Errore durante la chiusura del turno fiscale
					                   |%ErrorDescription%
					                   |Generazione del report non riuscita.';
					                   |de = 'Beim Schließen der Sitzung im Fiskalspeicher ist ein Fehler aufgetreten.
					                   |""%ErrorDescription%""
					                   |Bericht über den Fiskalspeicher wird nicht gebildet.'");
					MessageText = StrReplace(MessageText,"%ErrorDescription%",Output_Parameters[1]);
					CommonClientServer.MessageToUser(MessageText);
					
				Else
					
					DocumentArray = CloseCashCRSessionAtServer(CashCR, ErrorDescription);
					
					If ValueIsFilled(ErrorDescription)
					   AND UseWithoutEquipmentConnection Then
						
						CommonClientServer.MessageToUser(ErrorDescription);
						
					ElsIf ValueIsFilled(ErrorDescription)
						 AND Not UseWithoutEquipmentConnection Then
						
						MessageText = NStr("en = 'Session is closed on the fiscal register, but errors occurred when generating the retail sales report.
						                   |Additional description:
						                   |%AdditionalDetails%'; 
						                   |ru = 'Смена закрыта на фискальном регистраторе, но при формировании отчета о розничных продажах возникли ошибки.
						                   |Дополнительное
						                   |описание: %AdditionalDetails%';
						                   |pl = 'Sesja została zamknięta w rejestratorze fiskalnym, ale podczas tworzenia raportu o sprzedaży detalicznej wystąpiły błędy.
						                   |Dodatkowy opis:
						                   |%AdditionalDetails%';
						                   |es_ES = 'Sesión está cerrada en el registro fiscal pero han ocurrido errores al generar el informe de ventas minoristas.
						                   |Descripción adicional:
						                   |%AdditionalDetails%';
						                   |es_CO = 'Sesión está cerrada en el registro fiscal pero han ocurrido errores al generar el informe de ventas minoristas.
						                   |Descripción adicional:
						                   |%AdditionalDetails%';
						                   |tr = 'Oturum, mali kaydedicide kapatıldı, ancak perakende satış raporu oluşturulurken hatalar oluştu. 
						                   |Ek 
						                   |açıklama: %AdditionalDetails%';
						                   |it = 'La sessione è chiusa sul registratore fiscale, ma errori si sono registrati durante la generazione del report di vendita.
						                   |Descrizione
						                   |aggiuntiva: %AdditionalDetails%';
						                   |de = 'Die Sitzung wird im Fiskalspeicher geschlossen, es sind jedoch Fehler beim Generieren des Einzelhandelsumsatzberichts aufgetreten.
						                   |Zusätzliche Beschreibung:
						                   |%AdditionalDetails%'");
						MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
						CommonClientServer.MessageToUser(MessageText);
						
					EndIf;
					
					// Show all resulting documents to user.
					For Each Document In DocumentArray Do
						
						OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key", Document));
						
					EndDo;
					
				EndIf;
				
				If Not UseWithoutEquipmentConnection Then
					
					EquipmentManagerClient.DisableEquipmentById(
						UUID,
						DeviceIdentifier
					);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Report is not printed and session is not closed on the fiscal register.
				                   |Additional description:
				                   |%AdditionalDetails%'; 
				                   |ru = 'При подключении устройства произошла ошибка.
				                   |Отчет не напечатан и смена не закрыта на фискальном регистраторе.
				                   |Дополнительное
				                   |описание: %AdditionalDetails%';
				                   |pl = 'Podczas podłączania urządzenia wystąpił błąd.
				                   |Raport nie został wydrukowany i sesja nie była zamknięta w rejestratorze fiskalnym .
				                   |Dodatkowy opis:
				                   |%AdditionalDetails%';
				                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Informe no se ha imprimido y la sesión no está cerrada en el registro fiscal.
				                   |Descripción adicional:
				                   |%AdditionalDetails%';
				                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Informe no se ha imprimido y la sesión no está cerrada en el registro fiscal.
				                   |Descripción adicional:
				                   |%AdditionalDetails%';
				                   |tr = 'Cihaz bağlanırken hata oluştu.
				                   |Rapor yazdırılamadı ve mali kayıtta oturum kapatılmadı.
				                   |Ek açıklama:
				                   |%AdditionalDetails%';
				                   |it = 'Si è verificato un errore durante il collegamento del dispositivo.
				                   |Il report non viene stampato e la sessione non è chiusa sul registro fiscale.
				                   |Descrizione aggiuntiva:
				                   |%AdditionalDetails%';
				                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
				                   |Der Bericht wurde nicht gedruckt und die Sitzung wurde im Fiskalspeicher nicht geschlossen.
				                   |Zusätzliche Beschreibung:
				                   |%AdditionalDetails%'");
				MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'"
		);
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
	
	Notify("RefreshFormsAfterZReportIsDone");
	
EndProcedure

// Procedure - command handler "FundsIntroduction".
//
&AtClient
Procedure CashDeposition(Command)
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		InAmount = 0;
		
		WindowTitle = NStr("en = 'Deposit amount'; ru = 'Сумма внесения';pl = 'Wartość depozytu';es_ES = 'Importe del depósito';es_CO = 'Importe del depósito';tr = 'Depozito tutarı';it = 'Importo deposito';de = 'Einzahlungsbetrag'") + ", " + "%Currency%";
		WindowTitle = StrReplace(
			WindowTitle,
			"%Currency%",
			StructureStateCashCRSession.DocumentCurrencyPresentation
		);
		
		ShowInputNumber(New NotifyDescription("FundsIntroductionEnd", ThisObject, New Structure("InAmount", InAmount)), InAmount, WindowTitle, 15, 2);
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'"
		);
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FundsIntroductionEnd(Result1, AdditionalParameters) Export
	
	InAmount = ?(Result1 = Undefined, AdditionalParameters.InAmount, Result1);
	
	If (Result1 <> Undefined) Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If ValueIsFilled(DeviceIdentifier) Then
			FundsIntroductionFiscalRegisterConnectionsEnd(DeviceIdentifier, InAmount);
		Else
			NotifyDescription = New NotifyDescription("FundsIntroductionFiscalRegisterConnectionsEnd", ThisObject, InAmount);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
				NStr("en = 'Select a fiscal data recorder'; ru = 'Выберите фискальный регистратор';pl = 'Wybierz rejestrator danych fiskalnych';es_ES = 'Seleccionar un registrador de datos fiscales';es_CO = 'Seleccionar un registrador de datos fiscales';tr = 'Mali veri kaydediciyi seçin';it = 'Selezionare un registratore fiscale';de = 'Wählen Sie einen Steuer Datenschreiber'"), NStr("en = 'Fiscal data recorder is not connected.'; ru = 'Фискальный регистратор не подключен.';pl = 'Rejestrator fiskalny nie jest podłączony.';es_ES = 'Registrador de datos fiscales no está conectado.';es_CO = 'Registrador de datos fiscales no está conectado.';tr = 'Mali veri kaydedici bağlı değil.';it = 'Il registratore dati fiscale non è connesso.';de = 'Der Steuerdatenschreiber ist nicht angeschlossen.'"));
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure FundsIntroductionFiscalRegisterConnectionsEnd(DeviceIdentifier, Parameters) Export
	
	InAmount = Parameters;
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
		
		// Connect FR
		Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
		);
		
		If Result Then
			
			// Prepare data
			InputParameters  = New Array();
			Output_Parameters = Undefined;
			
			InputParameters.Add(1);
			InputParameters.Add(InAmount);
			
			// Print receipt.
			Result = EquipmentManagerClient.RunCommand(
			DeviceIdentifier,
			"Encash",
			InputParameters,
			Output_Parameters
			);
			
			If Not Result Then
				
				MessageText = NStr("en = 'When printing a receipt, an error occurred.
				                   |Receipt is not printed on the fiscal register.
				                   |Additional description:
				                   |%AdditionalDetails%'; 
				                   |ru = 'При печати чека произошла ошибка.
				                   |Чек не напечатан на фискальном регистраторе.
				                   |Дополнительное
				                   |описание: %AdditionalDetails%';
				                   |pl = 'Podczas drukowania paragonu wystąpił błąd.
				                   |Paragon nie został wydrukowany przez rejestrator fiskalny.
				                   |Dodatkowy opis:
				                   |%AdditionalDetails%';
				                   |es_ES = 'Imprimiendo un recibo, ha ocurrido un error.
				                   |Recibo no se ha imprimido en el registro fiscal.
				                   |Descripción adicional:
				                   |%AdditionalDetails%';
				                   |es_CO = 'Imprimiendo un recibo, ha ocurrido un error.
				                   |Recibo no se ha imprimido en el registro fiscal.
				                   |Descripción adicional:
				                   |%AdditionalDetails%';
				                   |tr = 'Rapor basılırken bir hata oluştu. 
				                   |Rapor mali kaydedicide yazdırılamıyor. 
				                   | Ek açıklama:
				                   |%AdditionalDetails%';
				                   |it = 'Durante la stampa di una ricevuta, si è verificato un errore.
				                   |La ricevuta non è stata stampata nel registratore fiscale.
				                   |Descrizione aggiuntiva:
				                   |%AdditionalDetails%';
				                   |de = 'Beim Drucken eines Belegs ist ein Fehler aufgetreten.
				                   |Der Beleg wird nicht auf das Fiskalspeicher gedruckt.
				                   |Zusätzliche Beschreibung:
				                   |%AdditionalDetails%'");
				MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
			// Disconnect FR
			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
			
		Else
			
			MessageText = NStr("en = 'An error occurred when connecting the device.
			                   |Receipt is not printed on the fiscal register.
			                   |Additional description:
			                   |%AdditionalDetails%'; 
			                   |ru = 'При подключении устройства произошла ошибка.
			                   |Чек не напечатан на фискальном регистраторе.
			                   |Дополнительное
			                   |описание: %AdditionalDetails%';
			                   |pl = 'Podczas podłączania urządzenia wystąpił błąd.
			                   |Paragon nie był wydrukowany przez rejestrator fiskalny. 
			                   |Dodatkowy opis:
			                   |%AdditionalDetails%';
			                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
			                   |Recibo no se ha imprimido en el registro fiscal.
			                   |Descripción adicional:
			                   |%AdditionalDetails%';
			                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
			                   |Recibo no se ha imprimido en el registro fiscal.
			                   |Descripción adicional:
			                   |%AdditionalDetails%';
			                   |tr = 'Cihaz bağlanırken hata oluştu.
			                   |Fiş mali kayıtta yazdırılamadı.
			                   | Ek açıklama:
			                   |%AdditionalDetails%';
			                   |it = 'Si è verificato un errore durante il collegamento del dispositivo.
			                   |La sessione non viene aperta sul registro fiscale.
			                   |Descrizione
			                   |Aggiuntiva: %AdditionalDetails%';
			                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
			                   |Der Beleg wird nicht auf den Fiskalspeicher  gedruckt.
			                   |Zusätzliche Beschreibung:
			                   |%AdditionalDetails%'");
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
			CommonClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsWithdrawal".
//
&AtClient
Procedure Withdrawal(Command)
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		WithdrawnAmount = 0;
		
		WindowTitle = NStr("en = 'Withdrawal amount'; ru = 'Сумма снятия';pl = 'Kwota wypłaty';es_ES = 'Importe del retiro';es_CO = 'Importe del retiro';tr = 'Para çekme tutarı';it = 'Importo prelievo';de = 'Abhebungsbetrag'") + ", " + "%Currency%";
		WindowTitle = StrReplace(WindowTitle,"%Currency%",StructureStateCashCRSession.DocumentCurrencyPresentation);
		
		ShowInputNumber(New NotifyDescription("CashWithdrawalEnd", ThisObject, New Structure("WithdrawnAmount", WithdrawnAmount)), WithdrawnAmount, WindowTitle, 15, 2);
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CashWithdrawalEnd(Result1, AdditionalParameters) Export
	
	WithdrawnAmount = ?(Result1 = Undefined, AdditionalParameters.WithdrawnAmount, Result1);
	
	If (Result1 <> Undefined) Then
		
		ErrorDescription = "";
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If ValueIsFilled(DeviceIdentifier) Then
			CashWithdrawalFiscalRegisterConnectionsEnd(DeviceIdentifier, WithdrawnAmount);
		Else
			NotifyDescription = New NotifyDescription("CashWithdrawalFiscalRegisterConnectionsEnd", ThisObject, WithdrawnAmount);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
				NStr("en = 'Select a fiscal data recorder'; ru = 'Выберите фискальный регистратор';pl = 'Wybierz rejestrator danych fiskalnych';es_ES = 'Seleccionar un registrador de datos fiscales';es_CO = 'Seleccionar un registrador de datos fiscales';tr = 'Mali veri kaydediciyi seçin';it = 'Selezionare un registratore fiscale';de = 'Wählen Sie einen Steuer Datenschreiber'"), NStr("en = 'Fiscal data recorder is not connected.'; ru = 'Фискальный регистратор не подключен.';pl = 'Rejestrator fiskalny nie jest podłączony.';es_ES = 'Registrador de datos fiscales no está conectado.';es_CO = 'Registrador de datos fiscales no está conectado.';tr = 'Mali veri kaydedici bağlı değil.';it = 'Il registratore dati fiscale non è connesso.';de = 'Der Steuerdatenschreiber ist nicht angeschlossen.'"));
		EndIf;
	
	EndIf;

EndProcedure

&AtClient
Procedure CashWithdrawalFiscalRegisterConnectionsEnd(DeviceIdentifier, Parameters) Export
	
	WithdrawnAmount = Parameters;
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
			
			// Connect FR
			Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
			);
			
			If Result Then
				
				// Prepare data
				InputParameters  = New Array();
				Output_Parameters = Undefined;
				
				InputParameters.Add(0);
				InputParameters.Add(WithdrawnAmount);
				
				// Print receipt.
				Result = EquipmentManagerClient.RunCommand(
					DeviceIdentifier,
					"Encash",
					InputParameters,
					Output_Parameters
				);
				
				If Not Result Then
					
					MessageText = NStr("en = 'When printing a receipt, an error occurred. Receipt is not printed on the fiscal register.
					                   |Additional description: %AdditionalDetails%'; 
					                   |ru = 'При печати чека произошла ошибка. Чек не напечатан на фискальном регистраторе. 
					                   |Дополнительное описание: %AdditionalDetails%';
					                   |pl = 'Podczas drukowania paragonu wystąpił błąd. Paragon nie został wydrukowany przez rejestrator fiskalny.
					                   |Dodatkowy opis: %AdditionalDetails%';
					                   |es_ES = 'Al imprimir un recibo, ha ocurrido un error. Recibo no se ha imprimido en el registro fiscal.
					                   |Descripción adicional: %AdditionalDetails%';
					                   |es_CO = 'Al imprimir un recibo, ha ocurrido un error. Recibo no se ha imprimido en el registro fiscal.
					                   |Descripción adicional: %AdditionalDetails%';
					                   |tr = 'Fiş yazdırılırken hata oluştu. Fiş mali kayıtta yazdırılamadı.
					                   |Ek açıklama: %AdditionalDetails%';
					                   |it = 'Si è verificato un errore durante la stampa di una ricevuta. La ricevuta non è stampata sul registratore fiscale.
					                   |Descrizione aggiuntiva: %AdditionalDetails%';
					                   |de = 'Beim Drucken eines Belegs ist ein Fehler aufgetreten. Der Beleg wird nicht auf das Fiskalspeicher gedruckt.
					                   |Zusätzliche Beschreibung: %AdditionalDetails%'");
					MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
					CommonClientServer.MessageToUser(MessageText);
					
				EndIf;
				
				// Disconnect FR
				EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Receipt is not printed on the fiscal register.
				                   |Additional description:
				                   |%AdditionalDetails%'; 
				                   |ru = 'При подключении устройства произошла ошибка.
				                   |Чек не напечатан на фискальном регистраторе.
				                   |Дополнительное
				                   |описание: %AdditionalDetails%';
				                   |pl = 'Podczas podłączania urządzenia wystąpił błąd.
				                   |Paragon nie był wydrukowany przez rejestrator fiskalny. 
				                   |Dodatkowy opis:
				                   |%AdditionalDetails%';
				                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Recibo no se ha imprimido en el registro fiscal.
				                   |Descripción adicional:
				                   |%AdditionalDetails%';
				                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
				                   |Recibo no se ha imprimido en el registro fiscal.
				                   |Descripción adicional:
				                   |%AdditionalDetails%';
				                   |tr = 'Cihaz bağlanırken hata oluştu.
				                   |Fiş mali kayıtta yazdırılamadı.
				                   | Ek açıklama:
				                   |%AdditionalDetails%';
				                   |it = 'Si è verificato un errore durante il collegamento del dispositivo.
				                   |La sessione non viene aperta sul registro fiscale.
				                   |Descrizione
				                   |Aggiuntiva: %AdditionalDetails%';
				                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
				                   |Der Beleg wird nicht auf den Fiskalspeicher gedruckt.
				                   |Zusätzliche Beschreibung:
				                   |%AdditionalDetails%'");
				MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
				CommonClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
	
EndProcedure

// Function gets cash session state on server.
//
&AtServerNoContext
Function GetCashCRSessionStateAtServer(CashCR)
	
	Return Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	
EndFunction

// Procedure updates cash session state on client.
//
&AtServer
Procedure UpdateCashCRSessionStateAtServer(CashCR)
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	If ValueIsFilled(StructureStateCashCRSession.CashCRSessionStatus) Then
		
		MessageText = NStr("en = 'Session No.%NumberOfSession%, Status: %SessionStatus% %ModifiedAt%, IN cash %CashInPettyCash% %Currency%'; ru = 'Номер сессии %NumberOfSession%, Статус: %SessionStatus% %ModifiedAt%, в валюте %CashInPettyCash% %Currency%';pl = 'Nr sesji%NumberOfSession%, Status: %SessionStatus% %ModifiedAt%, Gotówka %CashInPettyCash% %Currency%';es_ES = 'Número de la sesión %NumberOfSession%. Estado: %SessionStatus% %ModifiedAt%, EN efectivo %CashInPettyCash% %Currency%';es_CO = 'Número de la sesión %NumberOfSession%. Estado: %SessionStatus% %ModifiedAt%, EN efectivo %CashInPettyCash% %Currency%';tr = 'Session No.%NumberOfSession%, Status: %SessionStatus% %ModifiedAt%, IN cash %CashInPettyCash% %Currency%';it = 'Sessione No.%NumberOfSession%, Stato: %SessionStatus% %ModifiedAt%, In contante %CashInPettyCash% %Currency%';de = 'Sitzungsnummer %NumberOfSession%,Status: %SessionStatus% %ModifiedAt%, IN bar %CashInPettyCash% %Currency%'");
		MessageText = StrReplace(MessageText, "%NumberOfSession%", TrimAll(StructureStateCashCRSession.CashCRSessionNumber));
		MessageText = StrReplace(MessageText, "%SessionStatus%", StructureStateCashCRSession.CashCRSessionStatus);
		MessageText = StrReplace(MessageText, "%CashInPettyCash%", StructureStateCashCRSession.CashInPettyCash);
		MessageText = StrReplace(MessageText, "%Currency%", StructureStateCashCRSession.DocumentCurrencyPresentation);
		MessageText = StrReplace(MessageText, "%ModifiedAt%", Format(StructureStateCashCRSession.StatusModificationDate,"DF=dd.MM.yy HH:mm'"));
		
		StatusCashCRSession = MessageText;
		
	Else
		
		StatusCashCRSession = NStr("en = 'Shift is not opened.'; ru = 'Смена не открыта.';pl = 'Zmiana nie jest otwarta';es_ES = 'Turno no está abierto.';es_CO = 'Turno no está abierto.';tr = 'Vardiya açılmadı.';it = 'Il turno non è aperto';de = 'Änderung ist nicht offen.'");
		
	EndIf;
	
	// Form variable
	SessionIsOpen = StructureStateCashCRSession.SessionIsOpen;
	CurrentCashCRSession = StructureStateCashCRSession.CashCRSession;
	
	// Availability management.
	Items.DisableZReport.Visible		  = SessionIsOpen;
	Items.CashCRSessionOpen.Visible = Not SessionIsOpen AND ValueIsFilled(CashCR);
	
	Items.ReceiptsCRCreateReceipt.Enabled					= SessionIsOpen;
	Items.ReceiptsCRDocumentReturnSalesSlipCreateBasedOn.Enabled = SessionIsOpen;
	Items.SalesSlipsCopy.Enabled				= SessionIsOpen;
	Items.ContextMenuReceiptsCRCopy.Enabled = SessionIsOpen;
	
	Items.CashDeposition.Enabled = ValueIsFilled(CashCR);
	Items.Withdrawal.Enabled   = ValueIsFilled(CashCR);
	
EndProcedure

// Procedure - command handler "UpdateCashCRSessionState".
//
&AtClient
Procedure UpdateCashCRSessionState(Command)
	
	If Not ValueIsFilled(CashCR) Then
		Return;
	EndIf;
	
	UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
	
EndProcedure

// Procedure - command handler "OpenFiscalRegisterManagement".
//
&AtClient
Procedure OpenFiscalRegisterManagement(Command)
	
	OpenForm("Catalog.Peripherals.Form.CashRegisterShiftClosure");

EndProcedure

// Procedure - command handler "OpenPOSTerminalManagement".
//
&AtClient
Procedure OpenPOSTerminalManagement(Command)
	
	OpenForm("Catalog.Peripherals.Form.PaymentTerminalFunctions");

EndProcedure

// Procedure - form event handler "NotificationProcessing".
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName  = "RefreshFormsAfterZReportIsDone" Then
		Items.SalesSlips.Refresh();
		UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
		ReceiptsCROnActivateRowAtClient();
	ElsIf EventName = "RefreshSalesSlipDocumentsListForm" Then
		Items.SalesSlips.Refresh();
		UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
		ReceiptsCROnActivateRowAtClient();
	ElsIf EventName = "RefreshFormsAfterClosingCashCRSession" Then
		Items.SalesSlips.Refresh();
		UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
		ReceiptsCROnActivateRowAtClient();
	EndIf;
	
EndProcedure

// Procedure is intended to handle the "OnActivateRow" event of the SalesSlips list
//
&AtClient
Procedure ReceiptsCROnActivateRowAtClient()
	
	If StructureStateCashCRSession = Undefined Then
		UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
	EndIf;
	
	CurrentData = Items.SalesSlips.CurrentData;
	If CurrentData <> Undefined Then
		
		If Not CurrentData.Property("RowGroup")
			AND ValueIsFilled(CurrentData.SalesSlipNumber)
			AND ValueIsFilled(StructureStateCashCRSession)
			AND CurrentData.CashCRSession = StructureStateCashCRSession.CashCRSession
			AND Not CurrentData.ThereIsBillForReturn
			AND SessionIsOpen
			AND CurrentData.Type <> Type("DocumentRef.ProductReturn") Then
			
			Items.ReceiptsCRDocumentReturnSalesSlipCreateBasedOn.Enabled = True;
			Items.ContextMenuReceiptsCRDocumentProductReturnCreateBasedOn.Enabled = True;
			
		Else
			
			Items.ReceiptsCRDocumentReturnSalesSlipCreateBasedOn.Enabled = False;
			Items.ContextMenuReceiptsCRDocumentProductReturnCreateBasedOn.Enabled = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler "OnActivateRow" of the SalesSlips list.
//
&AtClient
Procedure ReceiptsCROnActivateRow(Item)
	
	ReceiptsCROnActivateRowAtClient();
	
EndProcedure

// Procedure is intended to handle the "OnChangeAtServer" event of the CurrentSessionOnlyFilter flag on server
//
&AtServer
Procedure CurrentSessionOnlyFilterOnChangeAtServer()
	
	SetDynamicListsFilter();
	
EndProcedure

// Procedure - event handler "OnChange" of the CurrentSessionOnlyFilter flag.
//
&AtClient
Procedure CurrentSessionOnlyFilterOnChange(Item)

	CurrentSessionOnlyFilterOnChangeAtServer();

EndProcedure

// Procedure - command handler "CreateReceipt".
//
&AtClient
Procedure CreateReceipt(Command)
	
	If SessionIsOpen Then
		OpenParameters = New Structure("Basis", New Structure("CashCR", CashCR));
		OpenForm("Document.SalesSlip.ObjectForm", OpenParameters);
	EndIf;
	
EndProcedure

#EndRegion
