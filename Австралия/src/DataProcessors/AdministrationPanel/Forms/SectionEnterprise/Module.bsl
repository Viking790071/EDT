
#Region Variables

&AtClient
Var RefreshInterface;

&AtClient
Var IdleHandlerParameters;

&AtClient
Var TimeConsumingOperationForm;

#EndRegion

#Region FormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonCached.ApplicationRunMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
	Items.FileFormatArchiving.ListChoiceMode = True;
	For Each FormatItem In Enums.ReportSaveFormats Do
		Items.FileFormatArchiving.ChoiceList.Add(FormatItem, String(FormatItem));
	EndDo;
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
	RefreshSubsidiaryCompanyEnabled();
	
	Items.CompanySettingsSettings.Enabled = ConstantsSet.UseSeveralCompanies;
	
EndProcedure

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	// If the AccountingBySubsidiaryCompany flag is set, then the company must be filled.
	If ConstantsSet.AccountingBySubsidiaryCompany AND NOT ValueIsFilled(ConstantsSet.ParentCompany) Then
		
		MessageText = NStr("en = 'The ""Keep accounting by company"" check box is selected, but the company is not filled in.'; ru = 'Установлен флажок ""Вести учет по организации"", но организация не заполнена!';pl = 'Pole wyboru ""Prowadzić rachunkowość według firmy"" jest zaznaczone, ale firma nie jest wypełniona.';es_ES = 'La casilla de verificación ""Mantener la contabilidad por empresa"" está seleccionada pero la empresa no está rellenada.';es_CO = 'La casilla de verificación ""Mantener la contabilidad por empresa"" está seleccionada pero la empresa no está rellenada.';tr = '""İş yerine göre muhasebe tut"" onay kutusu seçildi, ancak iş yeri doldurulmadı.';it = 'E'' selezionata l''opzione""Gestire la contabilità per azienda"", ma l''azienda non è compilata.';de = 'Das Kontrollkästchen ""Buchhaltung nach Firmen beibehalten"" ist aktiviert, die Firma ist jedoch nicht ausgefüllt.'");
		CommonClientServer.MessageToUser(MessageText, , "ConstantsSet.ParentCompany", , Cancel);
		
	EndIf;
	
	If ConstantsSet.ArchivePrintForms AND NOT ValueIsFilled(ConstantsSet.FileFormatArchiving) Then
		
		MessageText = NStr("en = 'The ""Archive print forms"" check box is selected, but the format for archiving is not filled in.'; ru = 'Флажок ""Архивировать печатные формы"" установлен, но формат архивации не указан.';pl = 'Zaznaczono pole wyboru ""Archiwizuj formularze wydruku"", ale nie wypełniono formatu archiwizacji.';es_ES = 'La casilla de verificación ""Archivar formularios de impresión"" está activada, pero el formato de archivo no se ha completado.';es_CO = 'La casilla de verificación ""Archivar formularios de impresión"" está activada, pero el formato de archivo no se ha completado.';tr = '""Yazdırma formlarını arşivle"" onay kutusu seçili, fakat arşivleme formatı doldurulmadı.';it = 'La casella di controllo ""Archivio moduli di stampa"" è selezionata, ma il formato per l''archiviazione non è compilato.';de = 'Das Kontrollkästchen ""Druckformulare archivieren"" ist aktiviert, das Format für die Archivierung ist jedoch nicht ausgefüllt.'");
		CommonClientServer.MessageToUser(MessageText, , "ConstantsSet.FileFormatArchiving", , Cancel);
		
	EndIf;
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange field UseSeveralDepartments.
//
&AtClient
Procedure FunctionalOptionAccountingByMultipleDepartmentsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field UseSeveralLinesOfBusiness.
//
&AtClient
Procedure AccountingByMultipleLinesOfBusinessOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field AddItemNumberToProductDescriptionOnPrinting.
//
&AtClient
Procedure ProductsSKUInContentOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field UseBudgeting.
//
&AtClient
Procedure FunctionalOptionUseBudgetingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field UseBarcodesInPrintForms.
//
&AtClient
Procedure FunctionalOptionUseBarcodesInPrintForms(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field FunctionalOptionFixedAssetsAccounting.
//
&AtClient
Procedure FunctionalOptionAccountingFixedAssetsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure FunctionalOptionUseCounterpartyContractTypesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseContractsWithCounterpartiesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseVIESVATNumberValidationOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseMultipleVATNumbersOnChange(Item)
	
	If Not ConstantsSet.UseMultipleVATNumbers Then 
		
		Companies = FindCompaniesWithMultipleVATNumbers();
		If Companies.Count() > 0 Then 
			
			CompaniesDescriptions = "";
			For Each Company In Companies Do
				CompaniesDescriptions = CompaniesDescriptions + Chars.CR + " - " + Company;
			EndDo;
			
			MessageText = NStr("en = 'Cannot turn off the ""Use multiple VAT IDs"" option because the following companies have multiple VAT IDs:'; ru = 'Отключение опции ""Использовать несколько номеров плательщика НДС"" невозможно, поскольку у следующих организаций имеется несколько номеров плательщика НДС:';pl = 'Nie można wyłączyć opcji ""Użycie kilku numerów VAT"" ponieważ następujące firmy mają kilka numerów VAT:';es_ES = 'No se puede desactivar la opción ""Usar múltiples identificadores del IVA"" porque las siguientes empresas tienen múltiples identificadores del IVA:';es_CO = 'No se puede desactivar la opción ""Usar múltiples identificadores del IVA"" porque las siguientes empresas tienen múltiples identificadores del IVA:';tr = '''''Çoklu KDV kodları kullan'''' seçeneği kapatılamadı çünkü aşağıdaki iş yerleri çoklu KDV kodları kullanıyor:';it = 'Impossibile disabilitare l''opzione ""Utilizza più P. Iva"" poiché le seguenti aziende hanno Id IVA multiple:';de = 'Kann die ""Mehrere USt.- IdNrn. anwenden"" Option nicht ausschalten, denn die folgenden Gesellschaften haben Mehrere USt.- IdNrn.:'") + CompaniesDescriptions;
			CommonClientServer.MessageToUser(MessageText,,"ConstantsSet.UseMultipleVATNumbers");
			
			ConstantsSet.UseMultipleVATNumbers = True;
			Return;
			
		EndIf;	
		
	EndIf;
	
	Attachable_OnAttributeChange(Item);

EndProcedure

// Procedure - event handler OnChange of the AccountingBySubsidiaryCompany field.
//
&AtClient
Procedure AccountingBySubsidiaryCompanyOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
	RefreshSubsidiaryCompanyEnabled();
	
EndProcedure

// Procedure - event handler OnChange of the UseSeveralCompanies field.
//
&AtClient
Procedure UseSeveralCompaniesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
	RefreshSubsidiaryCompanyEnabled();
	
	Items.CompanySettingsSettings.Enabled = ConstantsSet.UseSeveralCompanies;
	
EndProcedure

&AtClient
Procedure UseConsistentAuditTrailOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseRecurringInvoicingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure ArchivePrintFormsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure FileFormatArchivingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure CompareBeforeArchivingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure CheckStockBalanceOnPostingOnChange(Item)
	
	IsCheckStockBalanceOnPostingServer = GetCheckStockBalanceOnPostingServer();
	
	If Not ConstantsSet.CheckStockBalanceOnPosting 
		And GetCheckStockBalanceOnPostingServer() Then
		
		StockBalanceParameters = New Structure("ConstantValue, Item", IsCheckStockBalanceOnPostingServer, Item);
		
		Notification = New NotifyDescription("CheckStockBalanceOnPostingOnChangeEnd", ThisObject, StockBalanceParameters);
		
		TextQuestion = NStr("en = 'If you clear this check box, 
			|it is not guaranteed that the inventory cost is calculated correctly.
			|Do you want to continue?'; 
			|ru = 'Если этот флажок снят, 
			|правильность расчета себестоимости товарно-материальных ценностей не гарантируется.
			|Продолжить?';
			|pl = 'W razie wyczyszczenia tego pola wyboru, 
			|nie jest gwarantowane, że koszt zapasów jest obliczany poprawnie.
			|Czy chcesz kontynuować?';
			|es_ES = 'Si desmarca esta casilla de verificación, 
			|no se garantiza que el coste del inventario se calcule correctamente.
			|¿Quiere continuar?';
			|es_CO = 'Si desmarca esta casilla de verificación, 
			|no se garantiza que el coste del inventario se calcule correctamente.
			|¿Quiere continuar?';
			|tr = 'Bu onay kutusunu temizlerseniz
			|stok maliyeti doğru hesaplanmayabilir.
			|Devam etmek istiyor musunuz?';
			|it = 'Deselezionando questa casella di controllo, 
			|non è possibile garantire che il costo delle scorte venga calcolato correttamente.
			|Continuare?';
			|de = 'Wenn Sie dieses Kontrollkästchen deaktivieren, 
			|ist nicht garantiert, dass die Bestandskosten korrekt berechnet werden.
			|Möchten Sie fortfahren?'");
		
		Mode = QuestionDialogMode.OKCancel;
		ShowQueryBox(Notification, TextQuestion, Mode, 0);
		
		Return;
		
	EndIf;
	
	Attachable_OnAttributeChange(Item);

EndProcedure

&AtClient
Procedure CheckStockBalanceOnPostingOnChangeEnd(Result, StockBalanceParameters) Export
	
	If Result = DialogReturnCode.Cancel Then
		
		ConstantsSet.CheckStockBalanceOnPosting = StockBalanceParameters.ConstantValue;
		
		Return;
		
	Else 
		
		Attachable_OnAttributeChange(StockBalanceParameters.Item);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetCheckStockBalanceOnPostingServer()
	
	Return Constants.CheckStockBalanceOnPosting.Get();
	
EndFunction

&AtClient
Procedure SetClosingDateOnMonthEndClosingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseDefaultTypeOfAccountingOnChangeEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		Attachable_OnAttributeChange(AdditionalParameters.Item, , True);
	Else
		SetCurrentAccountingValues();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetCurrentAccountingValues()
	ConstantsSet.UseDefaultTypeOfAccounting	= Constants.UseDefaultTypeOfAccounting.Get();
	ConstantsSet.AccountingModuleSettings	= Constants.AccountingModuleSettings.Get();
	ConstantsSet.UseAccountingTemplates		= Constants.UseAccountingTemplates.Get();
EndProcedure

&AtClient
Procedure StartGLAccountClearing(AdditionalParameters)
	
	TimeConsuming = CreateTimeConsumingClearingGLAccountsOperation();
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.MessageText = NStr("en = 'Clearing GL account records...'; ru = 'Удаление бухгалтерских проводок...';pl = 'Wyczyszczenie wpisów konta księgowego...';es_ES = 'Eliminar los registros de la cuenta del libro mayor...';es_CO = 'Eliminar los registros de la cuenta del libro mayor...';tr = 'Muhasebe hesabı kayıtları siliniyor...';it = 'Cancellazione registrazioni conti mastro...';de = 'Einträge von Hauptbuch-Konto werden gelöscht...'");
	
	NotifyDescription = New NotifyDescription("GLAccountClearingOnComletion", ThisObject, AdditionalParameters);
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsuming, NotifyDescription, IdleParameters);
	
EndProcedure

&AtServer
Function CreateTimeConsumingClearingGLAccountsOperation()
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Clearing GL account records...'; ru = 'Удаление бухгалтерских проводок...';pl = 'Wyczyszczenie wpisów konta księgowego...';es_ES = 'Eliminar los registros de la cuenta del libro mayor...';es_CO = 'Eliminar los registros de la cuenta del libro mayor...';tr = 'Muhasebe hesabı kayıtları siliniyor...';it = 'Cancellazione registrazioni conti mastro...';de = 'Einträge von Hauptbuch-Konto werden gelöscht...'");
	
	ProcedureParameters = New Structure;
	
	Return TimeConsumingOperations.ExecuteInBackground("InfobaseUpdateDrive.ExecuteClearGLAccountsInRecords",
		ProcedureParameters, ExecutionParameters);
	
EndFunction

&AtClient
Procedure GLAccountClearingOnComletion(Result, AdditionParameters) Export
	
	If Result = Undefined Or Result.Status = "Canceled" Or Result.Status = "Error" Then
		
		If Result <> Undefined And Result.Property("DetailedErrorPresentation") Then
			CommonClientServer.MessageToUser(Result.DetailedErrorPresentation);
		EndIf;
		
		SetCurrentAccountingValues();
		
		Return;
		
	EndIf;
	
	SaveAttributesResult = New Structure;
	
	SetNewAccountingValues(AdditionParameters, SaveAttributesResult);
	
	If AdditionParameters.RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If SaveAttributesResult.Property("NotificationForms") Then
		Notify(SaveAttributesResult.NotificationForms.EventName,
			SaveAttributesResult.NotificationForms.Parameter,
			SaveAttributesResult.NotificationForms.Source);
	EndIf;
	
	RefreshReportsOptions();
	
EndProcedure

&AtServer
Procedure SetNewAccountingValues(AdditionParameters, SaveAttributesResult)
	
	SaveAttributeValue(AdditionParameters.AttributePathToData, SaveAttributesResult);
	
	SetEnabled(AdditionParameters.AttributePathToData);
	
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure OnCloseMappingDataProcessorForm(Result, AdditionalParameters) Export
	
	If ConstantsSet.EachGLAccountIsMappedToIncomeAndExpenseItem Then
		
		If Not AdditionalParameters = Undefined And AdditionalParameters.Property("ClearGLAccounts") Then
			StartGLAccountClearing(AdditionalParameters);
		EndIf;
		
	Else
		
		If Not AdditionalParameters = Undefined And AdditionalParameters.Property("ClearGLAccounts") Then
			ConstantsSet.UseDefaultTypeOfAccounting = True;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshReportsOptions()
	
	TimeConsuming = CreateTimeConsumingRefreshReportsOptions();
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsuming, , IdleParameters);
	
EndProcedure

&AtServer
Function CreateTimeConsumingRefreshReportsOptions()
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Refresh reports options...'; ru = 'Обновить варианты отчетов...';pl = 'Odśwież warianty raportu...';es_ES = 'Actualizar las opciones de los informes...';es_CO = 'Actualizar las opciones de los informes...';tr = 'Rapor seçeneklerini yenile...';it = 'Aggiornare le varianti di report...';de = 'Berichtsvarianten aktualisieren...'");
	
	ProcedureParameters = New Structure;
	
	Return TimeConsumingOperations.ExecuteInBackground("InfobaseUpdateDrive.ExecuteRefreshReportsOptions",
		ProcedureParameters, ExecutionParameters);
	
EndFunction

&AtClient
Procedure FunctionalOptionAccountingModuleSettingsOnChange(Item)
	
	ItemName = Item.Name;
	
	If (ItemName = "DoNotUseAccountingModule"
		Or ItemName = "UseTemplateBasedTypesOfAccounting")
		And ConstantsSet.UseDefaultTypeOfAccounting
		And CheckDefaultAccountingEntriesExists() Then
		
		Notification = New NotifyDescription(
			"UseDefaultTypeOfAccountingOnChangeEnd", 
			ThisObject,
			New Structure("Item", Item));
		
		MessageTemplate = NStr("en = 'After you select the ""%1"" option, GL accounts will be removed from business documents and catalogs.
			|The existing GL account entries will be permanently cleared. This change is irreversible.
			|Before you continue, it is highly recommended that you create the 1C:Drive backup copy.
			|Do you want to continue?'; 
			|ru = 'После выбора опции ""%1"" счета учета будут удалены из коммерческих документов и справочников.
			|Существующие бухгалтерские проводки будут удалены. Эти изменения необратимы.
			|Прежде чем продолжить, настоятельно рекомендуется создать резервную копию 1C:Drive.
			|Продолжить?';
			|pl = 'Po zaznaczeniu opcji ""%1"", Konta księgowe zostaną usunięte z dokumentów biznesowych i katalogów.
			|Istniejące wpisy kont księgowych zostaną na stałe usunięte. Ta zmiana jest nieodwracalna.
			|Zanim przejdziesz dalej, zaleca się utworzyć kopie zapasową 1C:Drive.
			|Czy chcesz kontynuować?';
			|es_ES = 'Después de seleccionar la variante ""%1"", las cuentas del libro mayor se eliminarán de los documentos comerciales y de los catálogos. 
			|Las entradas de diario de cuenta del libro mayor existentes se borrarán de forma permanente. Este cambio es irreversible. 
			|Antes de continuar, es muy recomendable crear una copia de respaldo de 1C:Drive. 
			|¿Quiere continuar?';
			|es_CO = 'Después de seleccionar la variante ""%1"", las cuentas del libro mayor se eliminarán de los documentos comerciales y de los catálogos. 
			|Las entradas de diario de cuenta del libro mayor existentes se borrarán de forma permanente. Este cambio es irreversible. 
			|Antes de continuar, es muy recomendable crear una copia de respaldo de 1C:Drive. 
			|¿Quiere continuar?';
			|tr = '""%1"" seçeneğini seçtiğinizde muhasebe hesapları iş belgelerinden ve kataloglardan çıkarılacak.
			|Mevcut muhasebe hesabı girişleri kalıcı olarak silinecek. Bu değişiklik geri alınamaz.
			|Devam etmeden önce, 1C:Drive yedeklemesi oluşturmanız önerilir.
			|Devam etmek istiyor musunuz?';
			|it = 'Dopo aver selezionato l''opzione ""%1"", i conti mastro saranno rimossi dai documenti aziendali e cataloghi.
			|Le voci di conti mastro esistenti saranno cancellate in modo permanente e irreversibile.
			|Prima di continuare, si consiglia di creare una copia di backup di 1C:Drive.
			|Continuare?';
			|de = 'Nachdem Sie die Option ""%1"" auswählen, werden die Hauptbuch-Konten aus Geschäftsdokumenten und Katalogen entfernt.
			|Die vorhandenen Einträge von Hauptbuch-Konto werden dauerhaft gelöscht. Diese Änderungen sind irreversibel.
			|Bevor Sie fortfahren, ist es höchstens empfehlenswert die 1C:Drive Sicherungskopie zu erstellen.
			| Möchten Sie fortfahren?'");
		
		ShowQueryBox(
			Notification,
			StrTemplate(MessageTemplate, String(ConstantsSet.AccountingModuleSettings)),
			QuestionDialogMode.YesNo,
			,
			DialogReturnCode.No);
		
	Else
		
		Attachable_OnAttributeChange(Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FunctionalOptionUseAccountingApprovalOnChange(Item)
	
	SetAccountingEntriesStatus();
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure SetAccountingEntriesStatus()
	
	If ConstantsSet.UseAccountingApproval
		And Not DriveServerCall.GetConstant("UseAccountingApproval") Then
		Text = NStr("en = 'The approval status will be set for the existing accounting entries. Do you want to continue?'; ru = 'Статус утверждения будет установлен для существующих бухгалтерских проводок. Продолжить?';pl = 'Status zatwierdzenia zostanie ustawiony dla istniejących wpisów księgowych. Czy chcesz kontynuować?';es_ES = 'El estado de aprobación será establecido para las entradas contables existentes. ¿Quiere continuar?';es_CO = 'El estado de aprobación será establecido para las entradas contables existentes. ¿Quiere continuar?';tr = 'Onay durumu mevcut muhasebe girişleri için ayarlanacak. Devam etmek istiyor musunuz?';it = 'Lo stato di approvazione sarà impostato per gli inserimenti contabili esistenti. Continuare?';de = 'Der Genehmigungsstatus wird für die vorhandenen Buchhaltungseinträge festgelegt. Möchten Sie fortsetzen?'");
		Notification = New NotifyDescription("SetAccountingEntriesStatusEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAccountingEntriesStatusEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		Result = SetAccountingEntriesStatusAtServer();
		
		If Not Result.JobCompleted Then
			
			JobID = Result.JobID;
			TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
			IdleHandlerParameters.IntervalIncreaseCoefficient = 1.2;
			AttachIdleHandler("Attachable_CheckJobCompletion", 1, True);
			TimeConsumingOperationForm = TimeConsumingOperationsClient.OpenTimeConsumingOperationForm(ThisObject, JobID);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

&AtServer
Function SetAccountingEntriesStatusAtServer()
	
	JobParameters = GetProcedureParameters();
	JobDescription = NStr("en = 'Change accounting entries statuses for multiple documents'; ru = 'Изменить статусы бухгалтерских проводок для нескольких документов';pl = 'Zmień statusy wpisów księgowych dla wielu dokumentów';es_ES = 'Cambiar el estado de las entradas contables para múltiples documentos';es_CO = 'Cambiar el estado de las entradas contables para múltiples documentos';tr = 'Birden fazla belgenin muhasebe girişleri durumunu değiştir';it = 'Modificare gli stati degli inserimenti contabili per documenti multipli';de = 'Status der Buchhaltungseinträge für mehrere Dokumente ändern'");
	
	Result = TimeConsumingOperations.StartBackgroundExecution(
		UUID,
		"AccountingApprovalServer.ChangeDocumentAccountingEntriesStatus",
		JobParameters,
		JobDescription);
	
	Return Result;
	
EndFunction

&AtServer
Function GetProcedureParameters()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingJournalEntries.Recorder AS Recorder
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries";
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	DocumentsArray = New Array;
	While Selection.Next() Do
		DocumentsArray.Add(Selection.Recorder);
	EndDo;
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("DocumentsArray", DocumentsArray);
	ProcedureParameters.Insert("Status", Enums.AccountingEntriesStatus.Approved);
	ProcedureParameters.Insert("UUID", UUID);
	
	Return ProcedureParameters;
	
EndFunction

&AtClient
Procedure FunctionalOptionPreventRepostingDocumentsWithApprovedAccountingEntriesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseProjectManagementOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseProjectUnitsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True, ClearGLAccounts = False)
	
	Result = OnAttributeChangeServer(Item.Name, ClearGLAccounts);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		
		Result.Property("Field", CustomMessage.Field);
		
		If CustomMessage.Field = "ConstantsSet.AccountingModuleSettings" Then
			CustomMessage.Field = "";
		EndIf;
		
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
	ElsIf ClearGLAccounts Then
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.MessageText = NStr("en = 'Clearing GL account records...'; ru = 'Удаление бухгалтерских проводок...';pl = 'Usuwanie wpisów konta księgowego...';es_ES = 'Eliminar los registros de la cuenta del libro mayor...';es_CO = 'Eliminar los registros de la cuenta del libro mayor...';tr = 'Muhasebe hesabı kayıtları siliniyor...';it = 'Cancellazione registrazioni conti mastro...';de = 'Einträge von Hauptbuch-Konto werden gelöscht...'");
		
		Result.Insert("RefreshingInterface", RefreshingInterface);
		
		NotifyDescription = New NotifyDescription("GLAccountClearingOnComletion", ThisObject, Result);
		TimeConsumingOperationsClient.WaitForCompletion(Result.TimeConsuming, NotifyDescription, IdleParameters);
		Return;
	EndIf;
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CheckJobCompletion()
 
	Try
		
		If TimeConsumingOperationForm.IsOpen() 
		 And TimeConsumingOperationForm.JobID = JobID Then
			
			If JobCompleted(JobID) Then 
				TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(TimeConsumingOperationForm);
			Else
				TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
				AttachIdleHandler("Attachable_CheckJobCompletion", IdleHandlerParameters.CurrentInterval, True);
			EndIf;
			
		EndIf;
		
	Except
		
		TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(TimeConsumingOperationForm);
		Raise;
		
	EndTry;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If NOT WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If NOT WebClient Then
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.IsSystemAdministrator Then
		
		If AttributePathToData = "ConstantsSet.UseSeveralCompanies" Or AttributePathToData = "" Then
			ConstantsSet.UseSeveralCompanies = GetFunctionalOption("UseSeveralCompanies");
			CommonClientServer.SetFormItemProperty(Items, "CatalogCompanies", "Enabled", ConstantsSet.UseSeveralCompanies);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseSeveralDepartments" Or AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "CatalogBusinessUnitsDepartment", "Enabled", ConstantsSet.UseSeveralDepartments);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseSeveralLinesOfBusiness" Or AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "CatalogLinesOfBusiness", "Enabled", ConstantsSet.UseSeveralLinesOfBusiness);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.FunctionalOptionUseVAT" Or AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "UseTaxInvoices", "Enabled", ConstantsSet.FunctionalOptionUseVAT);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseBarcodesInPrintForms" Or AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "CatalogBarcodeScanningActions", "Enabled", ConstantsSet.UseBarcodesInPrintForms);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.ArchivePrintForms" Or AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "FileFormatArchiving", "Enabled", ConstantsSet.ArchivePrintForms);
			CommonClientServer.SetFormItemProperty(Items, "PrintFormsArchivingSettingsButton", "Enabled", ConstantsSet.ArchivePrintForms);
			CommonClientServer.SetFormItemProperty(Items,
				"CompareBeforeArchiving",
				"Enabled",
				(ConstantsSet.ArchivePrintForms And ConstantsSet.FileFormatArchiving = Enums.ReportSaveFormats.MXL));
		EndIf;
		
		If AttributePathToData = "ConstantsSet.FileFormatArchiving" Or AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items,
				"CompareBeforeArchiving",
				"Enabled",
				(ConstantsSet.FileFormatArchiving = Enums.ReportSaveFormats.MXL));
			EndIf;
			
		If AttributePathToData = "ConstantsSet.UseAccountingApproval" Or AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items, "GroupPreventRepostingDocumentsWithApprovedAccountingEntries",
				"Enabled", ConstantsSet.UseAccountingApproval);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseProjectManagement" Or AttributePathToData = "" Then
			CommonClientServer.SetFormItemProperty(Items,
				"GroupProjectUnits",
				"Enabled",
				ConstantsSet.UseProjectManagement);
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.AccountingModuleSettings" Or AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "AccountingApproval",
			"Visible", ConstantsSet.AccountingModuleSettings <> Enums.AccountingModuleSettingsTypes.DoNotUseAccountingModule);
		
		CommonClientServer.SetFormItemProperty(Items, "GroupPreventRepostingDocumentsWithApprovedAccountingEntries",
			"Visible", Not ConstantsSet.UseAccountingTemplates);
		
		CommonClientServer.SetFormItemProperty(Items, "DataProcessorMapping", 
			"Visible", 
			ConstantsSet.UseDefaultTypeOfAccounting And Not ConstantsSet.EachGLAccountIsMappedToIncomeAndExpenseItem);
			
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName, ClearGLAccounts = False)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	ElsIf ClearGLAccounts Then
		TimeConsuming = CreateTimeConsumingClearingGLAccountsOperation();
		Result.Insert("TimeConsuming", TimeConsuming);
		Result.Insert("AttributePathToData", AttributePathToData);
	Else
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		
		ConstantManager	= Constants[ConstantName];
		ConstantValue	= ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
			
			If ConstantName = "UseBudgeting" Then
				
				NewValue = Constants.UseDefaultTypeOfAccounting.Get() And Constants.UseBudgeting.Get();
				Constants.UseGLAccountsBudgeting.Set(NewValue);
				
			ElsIf ConstantName = "AccountingModuleSettings" Then
				
				NewUseDefaultTypeOfAccountingValue =
					(ConstantValue = Enums.AccountingModuleSettingsTypes.UseDefaultTypeOfAccounting);
				
				NewUseAccountingTemplatesValue = 
					(ConstantValue = Enums.AccountingModuleSettingsTypes.UseTemplateBasedTypesOfAccounting);
					
				If ConstantsSet.UseAccountingApproval Then
					ConstantsSet.PreventRepostingDocumentsWithApprovedAccountingEntries = NewUseAccountingTemplatesValue;
					Constants.PreventRepostingDocumentsWithApprovedAccountingEntries.Set(NewUseAccountingTemplatesValue);
				EndIf;
					
				ConstantsSet.UseDefaultTypeOfAccounting = NewUseDefaultTypeOfAccountingValue;
				Constants.UseDefaultTypeOfAccounting.Set(NewUseDefaultTypeOfAccountingValue);
				
				ConstantsSet.UseAccountingTemplates = NewUseAccountingTemplatesValue;
				Constants.UseAccountingTemplates.Set(NewUseAccountingTemplatesValue);
				
				NewValue = NewUseDefaultTypeOfAccountingValue And Constants.UseBudgeting.Get();
				Constants.UseGLAccountsBudgeting.Set(NewValue);
				
				If ConstantValue = Enums.AccountingModuleSettingsTypes.DoNotUseAccountingModule Then
					
					ConstantsSet.UseAccountingApproval = False;
					ConstantsSet.PreventRepostingDocumentsWithApprovedAccountingEntries = False;
					Constants.UseAccountingApproval.Set(False);
					Constants.PreventRepostingDocumentsWithApprovedAccountingEntries.Set(False);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure("Value", ConstantValue), ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
		
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.UseSeveralDepartments" Then
		
		ConstantsSet.UseSeveralDepartments = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSeveralLinesOfBusiness" Then
		
		ConstantsSet.UseSeveralLinesOfBusiness = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseFixedAssets" Then
		
		ConstantsSet.UseFixedAssets = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionUseVAT" Then
		
		ConstantsSet.FunctionalOptionUseVAT = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseContractsWithCounterparties" Then
		
		ConstantsSet.UseContractsWithCounterparties = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSeveralCompanies" Then
		
		ConstantsSet.UseSeveralCompanies = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.AccountingBySubsidiaryCompany" Then
		
		ConstantsSet.AccountingBySubsidiaryCompany = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.ParentCompany" Then
		
		ConstantsSet.ParentCompany = CurrentValue;

	ElsIf AttributePathToData = "ConstantsSet.UseVIESVATNumberValidation" Then
		
		ConstantsSet.UseVIESVATNumberValidation = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseAccountingApproval" Then
		
		ConstantsSet.UseAccountingApproval = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseProjectManagement" Then
		
		ConstantsSet.UseProjectManagement = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseProjectUnits" Then
		
		ConstantsSet.UseProjectUnits = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.AccountingModuleSettings" Then
		
		ConstantsSet.AccountingModuleSettings = CurrentValue;
		
		NewUseDefaultTypeOfAccountingValue =
			(CurrentValue = Enums.AccountingModuleSettingsTypes.UseDefaultTypeOfAccounting);
			
		NewUseAccountingTemplatesValue =
			(CurrentValue = Enums.AccountingModuleSettingsTypes.UseTemplateBasedTypesOfAccounting);
			
		ConstantsSet.UseDefaultTypeOfAccounting = NewUseDefaultTypeOfAccountingValue;
		
		ConstantsSet.UseAccountingTemplates = NewUseAccountingTemplatesValue;
		
		If ConstantsSet.UseAccountingApproval Then
			ConstantsSet.PreventRepostingDocumentsWithApprovedAccountingEntries = NewUseAccountingTemplatesValue;
		EndIf;
	EndIf;
	
EndProcedure

// Check on the option disable possibility AccountingBySeveralLinesOfBusiness.
//
&AtServer
Function CancellationUncheckAccountingBySeveralLinesOfBusiness() 
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	OtherActivity = Catalogs.LinesOfBusiness.Other;
	SelectionOfBusinessLine = Catalogs.LinesOfBusiness.Select();
	While SelectionOfBusinessLine.Next() Do
		
		If SelectionOfBusinessLine.Ref <> Catalogs.LinesOfBusiness.MainLine
			AND SelectionOfBusinessLine.Ref <> OtherActivity Then
			
			RefArray = New Array;
			RefArray.Add(SelectionOfBusinessLine.Ref);
			RefsTable = FindByRef(RefArray);
			
			If RefsTable.Count() > 0 Then
				
				ErrorText = NStr("en = 'Lines of business which are different from the main one are used in the infobase. Cannot disable the option.'; ru = 'В базе используются направления деятельности, отличные от основного! Снятие опции запрещено!';pl = 'Baza informacyjna używa rodzajów działalności innych, niż główne. Nie można wyłączyć tej opcji.';es_ES = 'Líneas de negocio que son diferentes de la principal se utilizan en la infobase. No se puede desactivar la opción.';es_CO = 'Líneas de negocio que son diferentes de la principal se utilizan en la infobase. No se puede desactivar la opción.';tr = 'Infobase''de ana iş kolundan farklı iş kolları kullanılıyor. Bu seçenek devre dışı bırakılamaz.';it = 'Settori di attività che sono differenti da quelli principali inserite nell''infobase. Non può essere disabilitata l''opzione.';de = 'In der Infobase werden andere Geschäftszweige verwendet als die Hauptgeschäftszweige. Die Option kann nicht deaktiviert werden.'");
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return ErrorText;
	
EndFunction

// Check on the option disable possibility UseSeveralDepartments.
//
&AtServer
Function CancellationUncheckAccountingBySeveralDepartments() 
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	BusinessUnits.Ref
		|FROM
		|	Catalog.BusinessUnits AS BusinessUnits
		|WHERE
		|	BusinessUnits.StructuralUnitType = &StructuralUnitType
		|	AND BusinessUnits.Ref <> &MainDepartment"
	);
	
	Query.SetParameter("StructuralUnitType", Enums.BusinessUnitsTypes.Department);
	Query.SetParameter("MainDepartment", Catalogs.BusinessUnits.MainDepartment);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Departments which are different from the main one are used in the infobase. Cannot disable the option.'; ru = 'В базе используются подразделения, отличные от основного! Снятие опции запрещено!';pl = 'Baza informacyjna używa działów innych niż główne. Nie można wyłączyć tej opcji.';es_ES = 'Departamentos que son diferentes del principal se utilizan en la infobase. No se puede desactivar la opción.';es_CO = 'Departamentos que son diferentes del principal se utilizan en la infobase. No se puede desactivar la opción.';tr = 'Infobase''de ana bölümden farklı bölümler kullanılıyor. Bu seçenek devre dışı bırakılamaz.';it = 'Reparti che sono differenti da quello principale sono usati nel infobase. Non può essere disabilitata l''opzione.';de = 'Abteilungen, die sich von der Hauptabteilung unterscheiden, werden in der Infobase verwendet. Die Option kann nicht deaktiviert werden.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check on the option disable possibility UseFixedAssets.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingFixedAssets()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	FixedAssets.Company
		|FROM
		|	AccumulationRegister.FixedAssets AS FixedAssets"
	);
	
	QueryResult = Query.Execute();
	Cancel = NOT QueryResult.IsEmpty();
	
	If NOT Cancel Then
	
		Query = New Query(
			"SELECT TOP 1
			|	FixedAssetUsage.Company
			|FROM
			|	AccumulationRegister.FixedAssetUsage AS FixedAssetUsage"
		);
		
		QueryResult = Query.Execute();
		Cancel = NOT QueryResult.IsEmpty(); 
		
	EndIf;
	
	If Cancel Then
		
		ErrorText = NStr("en = 'There are capital asset movements in the infobase. Cannot clear the check box.'; ru = 'В базе присутствуют движения по внеоборотным активам! Снятие флага запрещено!';pl = 'W bazie informacyjnej istnieją ruchy zasobu kapitałowego. Nie można oczyścić pola wyboru.';es_ES = 'Hay movimientos de los activos del capital en la infobase. No se puede vaciar la casilla de verificación.';es_CO = 'Hay movimientos de los activos del capital en la infobase. No se puede vaciar la casilla de verificación.';tr = 'Veritabanında duran varlıkların hareketleri mevcut. Onay kutusu temizlenemiyor.';it = 'Ci sono movimenti di immobilizzazioni di caputale nell''infobase. Non può essere disabilitata l''opzione.';de = 'Es gibt Kapitalvermögensbewegungen in der Infobase. Das Kontrollkästchen kann nicht gelöscht werden.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check on the option disable possibility UseVAT.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseVAT()
		
	ErrorText = "";
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ISNULL(SUM(NestedQuery.VATAmountTurnover), 0) AS VATAmountTurnover
	|FROM
	|	(SELECT
	|		SalesTurnovers.VATAmountTurnover AS VATAmountTurnover
	|	FROM
	|		AccumulationRegister.Sales.Turnovers AS SalesTurnovers
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PurchasesTurnovers.VATAmountTurnover
	|	FROM
	|		AccumulationRegister.Purchases.Turnovers AS PurchasesTurnovers
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VATOutputTurnovers.VATAmountTurnover
	|	FROM
	|		AccumulationRegister.VATOutput.Turnovers AS VATOutputTurnovers
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		VATInputTurnovers.VATAmountTurnover
	|	FROM
	|		AccumulationRegister.VATInput.Turnovers AS VATInputTurnovers) AS NestedQuery";
	
	QueryResult = Query.Execute();

	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		
		If Selection.Next() 
			AND Selection.VATAmountTurnover > 0 Then		
				ErrorText = NStr("en = 'There are subject to VAT documents. Cannot clear the check box.'; ru = 'В базе присутствуют документы с НДС! Снятие флага запрещено!';pl = 'Istnieją dokumenty VAT. Nie można oczyścić pola wyboru.';es_ES = 'Hay documentos sujetos al IVA. No se puede vaciar la casilla de verificación.';es_CO = 'Hay documentos sujetos al IVA. No se puede vaciar la casilla de verificación.';tr = 'KDV''ye tabi belgeler mevcut. Onay kutusu temizlenemez.';it = 'Nella base ci sono documenti con IVA! E'' vietato rimuovere il contrassegno.';de = 'Es gibt umsatzsteuerpflichtige Dokumente. Das Kontrollkästchen kann nicht gelöscht werden.'");
		EndIf;
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check on the option disable possibility UseContractsWithCounterparties.
//
&AtServer
Function CancellationUncheckUseContractsWithCounterparties()
	
	ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckUseContractsWithCounterparties();
	
	Return ErrorText;
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	ErrorText = "";
	CurrentValue = True;
	
	// If there are references on departments unequal main department then it is not allowed to delete flag UseSeveralDepartments
	If AttributePathToData = "ConstantsSet.UseSeveralDepartments" Then		
		If Constants.UseSeveralDepartments.Get() <> ConstantsSet.UseSeveralDepartments
			AND (NOT ConstantsSet.UseSeveralDepartments) Then
				ErrorText = CancellationUncheckAccountingBySeveralDepartments();		
		EndIf;	
	EndIf;
	
	// If there are references on company unequal main company then it is not allowed to delete flag AccountingBySeveralLinesOfBusiness
	If AttributePathToData = "ConstantsSet.UseSeveralLinesOfBusiness" Then		
		If Constants.UseSeveralLinesOfBusiness.Get() <> ConstantsSet.UseSeveralLinesOfBusiness
			AND (NOT ConstantsSet.UseSeveralLinesOfBusiness) Then
				ErrorText = CancellationUncheckAccountingBySeveralLinesOfBusiness();	
		EndIf;
	EndIf;
		
	// If there are records by register "Property" or "Property selection" then it is not allowed to delete flag FunctionalOptionFixedAssetsAccounting	
	If AttributePathToData = "ConstantsSet.UseFixedAssets" Then
		If Constants.UseFixedAssets.Get() <> ConstantsSet.UseFixedAssets 
			AND (NOT ConstantsSet.UseFixedAssets) Then 	
				ErrorText = CancellationUncheckFunctionalOptionAccountingFixedAssets();
		EndIf;	
	EndIf;
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseVAT" Then		
		If Constants.FunctionalOptionUseVAT.Get() <> ConstantsSet.FunctionalOptionUseVAT 
			AND (NOT ConstantsSet.FunctionalOptionUseVAT) Then 
			
			ErrorText = CancellationUncheckFunctionalOptionUseVAT();
			
			If IsBlankString(ErrorText) 
				AND ConstantsSet.UseTaxInvoices Then
				// Turn off tax invoices
				ConstantsSet.UseTaxInvoices = False;
				SaveAttributeValue("ConstantsSet.UseTaxInvoices", New Structure());
			EndIf;			
		EndIf;		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseTaxInvoices" Then		
		If Constants.UseTaxInvoices.Get() <> ConstantsSet.UseTaxInvoices 
			AND ConstantsSet.UseTaxInvoices Then 		
				CommonClientServer.MessageToUser(
					NStr("en = 'Turn on ""Use tax invoice"" option in accounting policy of a company, for the changes to take effect.'; ru = 'Чтобы изменения вступили в силу, выберите опцию ""Использовать налоговые инвойсы"" в учетной политике компании.';pl = 'Włącz opcję ""Zastosuj faktury VAT"" w zasadach rachunkowości firmy, aby zmiany zaczęły obowiązywać.';es_ES = 'Activar la opción ""Utilizar la factura de impuestos"" en la política de contabilidad de una empresa, para que los cambios entren en vigor.';es_CO = 'Activar la opción ""Utilizar la factura fiscal"" en la política de contabilidad de una empresa, para que los cambios entren en vigor.';tr = 'Değişikliklerin yürürlüğe girmesi için bir iş yerinin muhasebe politikasında ""Vergi faturası kullan"" seçeneğini açın.';it = 'Attivare ""Uso della fattura fiscale"" nella politica contabile di un''azienda, per fare in modo che le modifiche abbiano effetto.';de = 'Aktivieren Sie die Option ""Steuerrechnung verwenden"" in der Bilanzierungsrichtlinie einer Firma, damit die Änderungen wirksam werden.'"));		
		EndIf;		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseContractsWithCounterparties" Then
		If Constants.UseContractsWithCounterparties.Get() <> ConstantsSet.UseContractsWithCounterparties 
			AND NOT ConstantsSet.UseContractsWithCounterparties Then
				ErrorText = CancellationUncheckUseContractsWithCounterparties();
		EndIf;
	EndIf;
	
	// If there are references to the company different from the main company, it is not allowed to clear the
	// UseSeveralCompanies flag.
	If AttributePathToData = "ConstantsSet.UseSeveralCompanies" Then
		If Constants.UseSeveralCompanies.Get() <> ConstantsSet.UseSeveralCompanies
			AND (NOT ConstantsSet.UseSeveralCompanies) Then
			
			ErrorText = CancellationUncheckUseSeveralCompanies();
			
			If IsBlankString(ErrorText) AND ConstantsSet.AccountingBySubsidiaryCompany Then
				
				ErrorText = CancellationUncheckAccountingBySubsidiaryCompany();
				
				If IsBlankString(ErrorText) Then
					ConstantsSet.AccountingBySubsidiaryCompany = False;
					SaveAttributeValue("ConstantsSet.AccountingBySubsidiaryCompany", New Structure());
					ConstantsSet.ParentCompany = Catalogs.Companies.EmptyRef();
					SaveAttributeValue("ConstantsSet.ParentCompany", New Structure());
				EndIf;
				
			EndIf;
			
		EndIf;
	EndIf;
	
	If AttributePathToData = "ConstantsSet.AccountingBySubsidiaryCompany" Then
		If Constants.AccountingBySubsidiaryCompany.Get() <> ConstantsSet.AccountingBySubsidiaryCompany Then
			
			// If there are any records of the company different from the selected company, it is not allowed to select AccountingBySubsidiaryCompany.
			If ConstantsSet.AccountingBySubsidiaryCompany Then
				
				ErrorText = CancellationSetAccountingBySubsidiaryCompanyChangeSubsidiaryCompany(AttributePathToData);
				CurrentValue = False;
				
				If IsBlankString(ErrorText) AND NOT ValueIsFilled(ConstantsSet.ParentCompany) Then
					ConstantsSet.ParentCompany = Catalogs.Companies.MainCompany;
					SaveAttributeValue("ConstantsSet.ParentCompany", New Structure());
				EndIf;
				
			// If there are any posted documents of the company different from the company, it is not allowed to clear AccountingBySubsidiaryCompany.
			Else
				
				ErrorText = CancellationUncheckAccountingBySubsidiaryCompany();
				
				If IsBlankString(ErrorText) Then
					ConstantsSet.ParentCompany = Catalogs.Companies.EmptyRef();
					SaveAttributeValue("ConstantsSet.ParentCompany", New Structure());
				EndIf;
				
			EndIf;
			
		EndIf;
	EndIf;
	
	If AttributePathToData = "ConstantsSet.ArchivePrintForms" Then
		If Constants.ArchivePrintForms.Get() <> ConstantsSet.ArchivePrintForms
			AND NOT ConstantsSet.ArchivePrintForms Then
			
			If ValueIsFilled(ConstantsSet.FileFormatArchiving) Then
				ConstantsSet.FileFormatArchiving = Enums.ReportSaveFormats.EmptyRef();
				SaveAttributeValue("ConstantsSet.FileFormatArchiving", New Structure());
			EndIf;
			
			If ConstantsSet.CompareBeforeArchiving Then
				ConstantsSet.CompareBeforeArchiving = False;
				SaveAttributeValue("ConstantsSet.CompareBeforeArchiving", New Structure());
			EndIf;
			
		EndIf;
	EndIf;
	
	If AttributePathToData = "ConstantsSet.FileFormatArchiving" Then
		If Constants.FileFormatArchiving.Get() <> ConstantsSet.FileFormatArchiving 
			AND ConstantsSet.FileFormatArchiving <> Enums.ReportSaveFormats.MXL Then
			
			If ConstantsSet.CompareBeforeArchiving Then
				ConstantsSet.CompareBeforeArchiving = False;
				SaveAttributeValue("ConstantsSet.CompareBeforeArchiving", New Structure());
			EndIf;
			
		EndIf;
	EndIf;
	
	// If there are any records of the company different from the selected company, it is not allowed to change Company.
	If AttributePathToData = "ConstantsSet.ParentCompany" Then
		If Constants.ParentCompany.Get() <> ConstantsSet.ParentCompany
			AND ValueIsFilled(ConstantsSet.ParentCompany)
			AND ValueIsFilled(Constants.ParentCompany.Get()) Then
			
			ErrorText = CancellationSetAccountingBySubsidiaryCompanyChangeSubsidiaryCompany(AttributePathToData);
			CurrentValue = Constants.ParentCompany.Get();
			
		EndIf;
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseAccountingApproval" Then
		If Constants.UseAccountingApproval.Get() <> ConstantsSet.UseAccountingApproval
			And (Not ConstantsSet.UseAccountingApproval) Then
			ErrorText = CancellationUncheckUseAccountingApproval();
		EndIf;
	EndIf;
	
	If AttributePathToData = "ConstantsSet.AccountingModuleSettings" Then
		
		If Constants.AccountingModuleSettings.UseTemplatesIsEnabled()
			And Constants.AccountingModuleSettings.Get() <> ConstantsSet.AccountingModuleSettings Then
			
			ErrorText = CheckEntriesOfAccountingModuleSettings();
			CurrentValue = Constants.AccountingModuleSettings.Get();
			
			If IsBlankString(ErrorText)
				And ConstantsSet.AccountingModuleSettings = Enums.AccountingModuleSettingsTypes.UseDefaultTypeOfAccounting Then
				ErrorText = CheckAccountingDocumentsExist();
			EndIf;
			
			If IsBlankString(ErrorText) Then
				SaveAttributeValue("ConstantsSet.AccountingModuleSettings", New Structure());
			EndIf;
			
		ElsIf Not Constants.AccountingModuleSettings.RegisterAccountingEntriesIsEnabled()
			And ConstantsSet.AccountingModuleSettings = Enums.AccountingModuleSettingsTypes.UseDefaultTypeOfAccounting Then
			ErrorText = CheckAccountingDocumentsExist();
			CurrentValue = Constants.AccountingModuleSettings.Get();
			If IsBlankString(ErrorText) Then
				SaveAttributeValue("ConstantsSet.AccountingModuleSettings", New Structure());
			EndIf;
		EndIf;
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseProjectManagement" Then
		If Constants.UseProjectManagement.Get() <> ConstantsSet.UseProjectManagement
			And Not ConstantsSet.UseProjectManagement Then
			
			If ConstantsSet.UseProjectUnits Then
				ConstantsSet.UseProjectUnits = False;
				SaveAttributeValue("ConstantsSet.UseProjectUnits", New Structure());
			EndIf;
			
		EndIf;
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		Result.Insert("Field",			AttributePathToData);
		Result.Insert("ErrorText",		ErrorText);
		Result.Insert("CurrentValue",	CurrentValue);
	EndIf;
		
EndFunction

// Procedure updates the availability of the Company flag RunAccountingBySubsidiaryCompany.
//
&AtClient
Procedure RefreshSubsidiaryCompanyEnabled()
	
	Items.ParentCompany.Enabled = ConstantsSet.AccountingBySubsidiaryCompany;
	Items.ParentCompany.AutoChoiceIncomplete = ConstantsSet.AccountingBySubsidiaryCompany;
	Items.ParentCompany.AutoMarkIncomplete = ConstantsSet.AccountingBySubsidiaryCompany;
	
EndProcedure

// Check on the possibility to disable the UseSeveralCompanies option.
//
&AtServer
Function CancellationUncheckUseSeveralCompanies()
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	MainCompany = Catalogs.Companies.MainCompany;
	
	SelectionCompanies = Catalogs.Companies.Select();
	While SelectionCompanies.Next() Do
		
		If SelectionCompanies.Ref <> MainCompany Then
			
			RefArray = New Array;
			RefArray.Add(SelectionCompanies.Ref);
			RefsTable = FindByRef(RefArray);
			
			If RefsTable.Count() > 0 Then
				
				ErrorText = NStr("en = 'Companies that differ from the main one are used in the infobase. Cannot clear the check box.'; ru = 'В базе используются организации, отличные от основной! Снятие опции запрещено!';pl = 'Baza informacyjna używa firm, które różnią się od firmy głównej. Nie można oczyścić pola wyboru.';es_ES = 'Empresas que son diferentes de la principal se utilizan en el infobase. No se puede vaciar la casilla de verificación.';es_CO = 'Empresas que son diferentes de la principal se utilizan en el infobase. No se puede vaciar la casilla de verificación.';tr = 'Infobase''de ana iş yerinden farklı iş yerleri kullanılıyor. Onay kutusu temizlenemez.';it = 'Il database utilizza aziende diverse da quella principale! La rimozione dell''opzione è vietata!';de = 'Von der Hauptversion abweichende Firmen werden in der Infobase verwendet. Das Kontrollkästchen kann nicht gelöscht werden.'");
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return ErrorText;
	
EndFunction

// Check on the possibility to change the established company.
//
&AtServer
Function CancellationSetAccountingBySubsidiaryCompanyChangeSubsidiaryCompany(FieldName)
	
	ErrorText = "";
	ParentCompany = ConstantsSet.ParentCompany;
	AccumulationRegistersCounter = 0;
	AreRecords = False;
	Query = New Query;
	Query.SetParameter("ParentCompany", ParentCompany);
	
	For Each AccumulationRegister In Metadata.AccumulationRegisters Do
		
		If AccumulationRegister = AccumulationRegisters.Workload Then
			Continue;
		EndIf;
			
		Query.Text = Query.Text + 
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1", 
				"UNION ALL 
				|
				|SELECT TOP 1 ") + "
				|
				|	AccumulationRegister" + AccumulationRegister.Name + ".Company
				|FROM
				|	AccumulationRegister." + AccumulationRegister.Name + " AS " + "AccumulationRegister" + AccumulationRegister.Name + "
				|WHERE
				|	AccumulationRegister" + AccumulationRegister.Name + ".Company <> &ParentCompany
				|";
		
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			AccumulationRegistersCounter = 0;
			Try
				QueryResult = Query.Execute();
				AreRecords = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
		
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except
		
		EndTry;
	EndIf;
	
	If AreRecords Then
		ErrorText = NStr("en = 'Records are registered for a company that is different from the company in the infobase. Cannot change the parameter.'; ru = 'В базе есть движения от организации, отличной от компании! Изменение параметра запрещено!';pl = 'Istnieją wpisy zarejestrowane dla firmy inne niż firma w bazie informacyjnej. Nie można zmienić parametru.';es_ES = 'Grabaciones se han registrado para una empresa que es diferente de la empresa en la infobase. No se puede cambiar el parámetro.';es_CO = 'Grabaciones se han registrado para una empresa que es diferente de la empresa en la infobase. No se puede cambiar el parámetro.';tr = 'Infobase''deki iş yerinden farklı bir iş yeri için kayıtlar mevcut. Parametre değiştirilemiyor.';it = 'Nel database ci sono movimenti da azienda diversa da quella presente nel database! La modifica del parametro è vietata!';de = 'Datensätze werden für eine Firma registriert, die sich von der Firma in der Infobase unterscheidet. Kann den Parameter nicht ändern.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check on the possibility to disable the AccountingBySubsidiaryCompany option.
//
&AtServer
Function CancellationUncheckAccountingBySubsidiaryCompany()
	
	ErrorText = "";
	ParentCompany = Constants.ParentCompany.Get();
	DocumentsCounter = 0;
	Query = New Query;
	For Each Doc In Metadata.Documents Do
		
		If Doc.Posting = Metadata.ObjectProperties.Posting.Deny Then
			Continue;
		EndIf;

		Query.Text = Query.Text +
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1",
				"UNION ALL
				|
				|SELECT TOP 1 ") + "
				|
				|	Document" + Doc.Name + ".Ref FROM Document." + Doc.Name + " AS " + "Document" + Doc.Name + "
				|	WHERE document" + Doc.Name + ".Company
				|	<> &ParentCompany AND Document" + Doc.Name + ".Posted
				|";
		
		DocumentsCounter = DocumentsCounter + 1;
		
		If DocumentsCounter > 3 Then
			DocumentsCounter = 0;
			Try
				Query.SetParameter("ParentCompany", ParentCompany);
				QueryResult = Query.Execute();
				AreDocuments = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreDocuments Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
		
	EndDo;
	
	If DocumentsCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			AreDocuments = Not QueryResult.IsEmpty();
		Except
			
		EndTry;
	EndIf;
	
	If AreDocuments Then
		ErrorText = NStr("en = 'There are posted documents of a company which differs from the company in the infobase. You cannot clear the ""Company accounting"" check box.'; ru = 'В базе есть проведенные документы от организации, отличной от компании! Снятие флага ""Учет по компании"" запрещено!';pl = 'Istnieją zaksięgowane dokumenty firmy, która różni się od firmy w bazie informacyjnej. Nie można oczyścić pola wyboru ""Rachunkowość Spółki"".';es_ES = 'Hay documentos enviado de una empresa que es diferente de la empresa en la infobase. Usted no puede vaciar la casilla de verificación ""Contabilidad de la empresa"".';es_CO = 'Hay documentos enviado de una empresa que es diferente de la empresa en la infobase. Usted no puede vaciar la casilla de verificación ""Contabilidad de la empresa"".';tr = 'Infobase''deki iş yerinden farklı bir iş yerinin kayıtlı belgeleri mevcut. ""İş yeri muhasebesi"" onay kutusu temizlenemez.';it = 'Ci sono documenti pubblicati di un''azienda che si differenzia dalla azienda nel database. Non è possibile deselezionare la casella di controllo ""Contabilità Aziendale"".';de = 'Es gibt gebuchte Dokumente einer Firma, die sich von der Firma in der Infobase unterscheidet. Sie können das Kontrollkästchen ""Firmenbuchhaltung"" nicht deaktivieren.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CancellationUncheckUseAccountingApproval() 
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	DocumentAccountingEntriesStatuses.Recorder AS Recorder
	|FROM
	|	InformationRegister.DocumentAccountingEntriesStatuses AS DocumentAccountingEntriesStatuses";
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		ErrorText = NStr("en = 'Cannot clear the checkbox. Accounting entries are already approved or pending approval.'; ru = 'Не удалось снять флажок. Бухгалтерские проводки уже утверждены или ожидают утверждения.';pl = 'Nie można odznaczyć pola wyboru. Wpisy księgowe są już zatwierdzone lub czekają na zatwierdzenie.';es_ES = 'No se puede desmarcar la casilla de verificación. Las entradas de diario ya están aprobadas o pendientes de aprobación.';es_CO = 'No se puede desmarcar la casilla de verificación. Las entradas de diario ya están aprobadas o pendientes de aprobación.';tr = 'Onay kutusu temizlenemiyor. Muhasebe girişleri zaten onaylandı veya onay bekliyor.';it = 'Impossibile deselezionare la casella di controllo. Le voci di contabilità sono già approvate o l''approvazione è in pendenza.';de = 'Fehler beim Deaktivieren des Kontrollkästchens. Buchungen sind bereits genehmigt oder auf Genehmigung wartend.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CheckEntriesOfAccountingModuleSettings()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	AccountingJournalEntriesSimple.Recorder AS Recorder
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple AS AccountingJournalEntriesSimple
	|WHERE
	|	AccountingJournalEntriesSimple.Active
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountingJournalEntriesCompound.Recorder
	|FROM
	|	AccountingRegister.AccountingJournalEntriesCompound AS AccountingJournalEntriesCompound
	|WHERE
	|	AccountingJournalEntriesCompound.Active
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountingJournalEntries.Recorder
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.TypeOfAccounting <> VALUE(Catalog.TypesOfAccounting.emptyref)
	|	AND AccountingJournalEntries.Active";
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		ErrorText = NStr("en = 'Cannot save the changes. The template-based accounting entries are already recorded.'; ru = 'Не удалось сохранить изменения. Бухгалтерские проводки, созданные по шаблону, уже внесены в систему.';pl = 'Nie można zapisać zmian. Wpisy księgowe na podstawie szablonu są już zapisane.';es_ES = 'No se pueden guardar los cambios. Las entradas de diario basadas en plantillas ya están registradas.';es_CO = 'No se pueden guardar los cambios. Las entradas de diario basadas en plantillas ya están registradas.';tr = 'Değişiklikler kaydedilemiyor. Şablon bazlı muhasebe girişi kayıtları var.';it = 'Impossibile salvare le modifiche. Le voci di contabilità basate su modello sono già registrate.';de = 'Fehler beim Speichern von Änderungen. Die auf Vorlage basierten Buchungen sind bereits eingetragen.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CheckAccountingDocumentsExist()
	
	ErrorText = "";
	
	RecordersNameArray = New Array;
	
	AccountingJournalEntries		 = Metadata.AccountingRegisters.AccountingJournalEntries;
	AccountingJournalEntriesRecorder = AccountingJournalEntries.StandardAttributes.Recorder;
	RecorderTypes					 = AccountingJournalEntriesRecorder.Type.Types();
	
	For Each Type In RecorderTypes Do
		
		DocumentMetadata = Metadata.FindByType(Type);
		
		If DocumentMetadata <> Undefined Then
			RecordersNameArray.Add(DocumentMetadata.FullName());
		EndIf;
		
	EndDo;
	
	If RecordersNameArray.Count() > 0 Then
		
		QueryTemplate =
		"SELECT TOP 1
		|	DocumentTable.Ref AS Ref
		|FROM
		|	DocumentName AS DocumentTable
		|WHERE
		|	DocumentTable.Posted";
		
		QueryText = "";
		
		QueryExist = False;
		
		For Each RecorderName In RecordersNameArray Do
			
			If QueryExist Then
				QueryText = QueryText + DriveClientServer.GetQueryUnion();
			Else
				QueryExist = True;
			EndIf;
			
			QueryText = QueryText + StrReplace(QueryTemplate, "DocumentName", RecorderName);
		EndDo;
		
		Query = New Query(QueryText);
		SetPrivilegedMode(True);
		QueryResult = Query.Execute();
		SetPrivilegedMode(False);
		
		If Not QueryResult.IsEmpty() Then
			ErrorText = NStr("en = 'Cannot save the changes. The business documents that are source documents of accounting entries are already recorded.'; ru = 'Не удалось сохранить изменения. Коммерческие документы, являющиеся первичными документами бухгалтерских проводок, уже зарегистрированы.';pl = 'Nie można zapisać zmian. Dokumenty biznesowe, które są źródłowymi dokumentami wpisów księgowych są już zapisane.';es_ES = 'No se pueden guardar los cambios. Los documentos comerciales que son documentos de fuente de entradas contables ya están registrados.';es_CO = 'No se pueden guardar los cambios. Los documentos comerciales que son documentos de fuente de entradas contables ya están registrados.';tr = 'Değişiklikler kaydedilemiyor. Muhasebe girişlerinin kaynak belgeleri olan iş belgelerinin kayıtları var.';it = 'Impossibile salvare le modifiche. I documenti aziendali documenti fonte delle voci di contabilità sono già registrati.';de = 'Fehler beim Speichern von Änderungen. Die Geschäftsvorlagen die Quelldokumente von Buchungen sind, sind bereits eingetragen.'");
		EndIf;
	
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CheckDefaultAccountingEntriesExists()
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	AccountingJournalEntries.Recorder AS Recorder
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.TypeOfAccounting = VALUE(Catalog.TypesOfAccounting.EmptyRef)";
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

#EndRegion

#Region FormCommandsEventHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogCompanies(Command)
	
	OpenForm("Catalog.Companies.ListForm");
	
EndProcedure

&AtClient
Procedure DataProcessorMapping(Command)
	OpenForm("DataProcessor.MappingGLAccountsToIncomeAndExpenseItems.Form.Form");
EndProcedure

// Procedure - command handler CatalogBusinessUnitsDepartment.
//
&AtClient
Procedure CatalogBusinessUnitsDepartment(Command)
	
	FilterStructure = New Structure("StructuralUnitType", PredefinedValue("Enum.BusinessUnitsTypes.Department"));
	OpenForm("Catalog.BusinessUnits.ListForm", New Structure("Filter", FilterStructure));
	
EndProcedure

&AtClient
Procedure CatalogBarcodeScanningActions(Command)
	OpenForm("Catalog.BarcodeScanningActions.ListForm");
EndProcedure

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogLinesOfBusiness(Command)
	
	OpenForm("Catalog.LinesOfBusiness.ListForm");
	
EndProcedure

// Procedure - command handler CatalogJobAndEventStatuses.
//
&AtClient
Procedure CatalogJobAndEventStatuses(Command)
	
	OpenForm("Catalog.JobAndEventStatuses.ListForm");
	
EndProcedure

&AtClient
Procedure PrintFormsArchivingSettings(Command)
	
	OpenForm("DataProcessor.PrintFormsArchivingSettings.Form.PrintFormsArchivingListForm");
	
EndProcedure

&AtServerNoContext
Function FindCompaniesWithMultipleVATNumbers()
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	CompaniesVATNumbers.Ref AS Ref
	|FROM
	|	Catalog.Companies.VATNumbers AS CompaniesVATNumbers
	|
	|GROUP BY
	|	CompaniesVATNumbers.Ref
	|
	|HAVING
	|	COUNT(CompaniesVATNumbers.LineNumber) > 1";
	
	Companies = Query.Execute().Unload();
	Return Companies.UnloadColumn("Ref");
	
EndFunction

#EndRegion

