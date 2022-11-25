#Region Variables

&AtClient
Var IdleHandlerParameters;
&AtClient
Var LongOperationForm;

#EndRegion

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(JobID) Then
			TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(LongOperationForm);
			StructureDataAtClient = ImportPreparedData();
			ImportPreparedDataAtClient(StructureDataAtClient);
		Else
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution", 
				IdleHandlerParameters.CurrentInterval, 
				True);
		EndIf;
	Except
		TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(LongOperationForm);
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function BankClassifierHasItems()
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	BankClassifier.Ref AS Ref
		|FROM
		|	Catalog.BankClassifier AS BankClassifier
		|WHERE
		|	NOT BankClassifier.DeletionMark";
	
	Return Not Query.Execute().IsEmpty(); 
	
EndFunction

&AtClient
Procedure ImportPreparedDataAtClient(DataStructure)
	
	If TypeOf(DataStructure) <> Type("Structure") Then
		Return;
	EndIf;
	
	If DataStructure.Property("SuccessfullyUpdated") Then
		
		NotificationText = NStr("en = 'Banks are updated from classifier'; ru = 'Банки успешно обновлены из классификатора';pl = 'Banki są aktualizowane z klasyfikatora';es_ES = 'Bancos se han actualizado desde el clasificador';es_CO = 'Bancos se han actualizado desde el clasificador';tr = 'Bankalar sınıflandırıcıdan güncellendi';it = 'Le banche vengono aggiornate dal classificatore';de = 'Banken werden vom Klassifikator aktualisiert'");
		ShowUserNotification("Update",, NotificationText);
		
	EndIf;
	
	Notify("RefreshAfterAdd");
	
EndProcedure

&AtServer
Function ImportPreparedData()
	
	StructureDataAtClient = New Structure();
	
	DataStructure = GetFromTempStorage(StorageAddress);
	If TypeOf(DataStructure) <> Type("Structure") Then
		Return Undefined;
	EndIf;
	
	If DataStructure.Property("SuccessfullyUpdated") Then
		StructureDataAtClient.Insert("SuccessfullyUpdated", DataStructure.SuccessfullyUpdated);
	EndIf;
	
	Return StructureDataAtClient;
	
EndFunction

&AtServer
Function RunOnServer(FileInfobase)
	
	ParametersStructure = New Structure();
	
	If FileInfobase Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		Catalogs.Banks.RefreshBanksFromClassifier(ParametersStructure, StorageAddress);
		Result = New Structure("Status", "Completed");
	Else
		ProcedureName = "Catalogs.Banks.RefreshBanksFromClassifier";
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
		ExecutionParameters.BackgroundJobDescription = NStr("en = 'Update of the banks from classifier'; ru = 'Обновление банков из классификатора';pl = 'Aktualizacja banków z klasyfikatora';es_ES = 'Actualización de los bancos desde el clasificador';es_CO = 'Actualización de los bancos desde el clasificador';tr = 'Bankaların sınıflandırıcıdan güncellenmesi';it = 'Aggiornamento delle banche dal classificatore';de = 'Aktualisierung der Banken vom Klassifikator'");
		
		Result = TimeConsumingOperations.ExecuteInBackground(ProcedureName, ParametersStructure, ExecutionParameters);
		
		StorageAddress       = Result.ResultAddress;
		JobID = Result.JobID;
	EndIf;
	
	If Result.Status = "Completed" Then
		Result.Insert("StructureDataClient", ImportPreparedData());
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshAfterAdd" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure PickFromClassifier(Command)
	
	FormParameters = New Structure("CloseOnChoice, MultipleChoice", False, True);
	OpenForm("Catalog.BankClassifier.ChoiceForm", FormParameters, ThisForm);

EndProcedure

&AtClient
Procedure UpdateFromClassifier(Command)
	
	If Not BanksHaveBeenUpdatedFromClassifier Then
		
		QuestionText = NStr("en = 'All records except manually created will be updated from the bank classfifier. 
		                    |In order to disable automatic updates for a given record, click ""Enable editing"" on the bank item form.
		                    |Do you want to continue?'; 
		                    |ru = 'Произойдет обновление всех банков из классификатора.
		                    |В дальнейшем, для исключения банка из автоматического обновления, необходимо включить признак ручного изменения (команда ""Изменить"").
		                    |Продолжить?';
		                    |pl = 'Wszystkie zapisy oprócz utworzonych ręcznie będą aktualizowane z klasyfikatora banków.
		                    |Aby wyłączyć automatyczne aktualizacje dla danego zapisu, kliknij ""Włącz edycję"" w formularzu bankowym.
		                    |Czy chcesz kontynuować?';
		                    |es_ES = 'Todos los registros, excepto a aquellos creados manualmente, se actualizarán desde el clasificador de bancos. 
		                    |Para desactivar las actualizaciones automáticas para un registro dado, hacer clic en ""Activar la edición"" en el formulario del artículo del banco.
		                    |¿Quiere continuar?';
		                    |es_CO = 'Todos los registros, excepto a aquellos creados manualmente, se actualizarán desde el clasificador de bancos. 
		                    |Para desactivar las actualizaciones automáticas para un registro dado, hacer clic en ""Activar la edición"" en el formulario del artículo del banco.
		                    |¿Quiere continuar?';
		                    |tr = 'Manuel olarak oluşturulanlar dışındaki tüm kayıtlar, banka sınıflandırıcıdan güncellenecek.
		                    |Belirli bir kaydın otomatik güncellemesini devre dışı bırakmak için banka öğe formundaki ""Düzenlemeyi etkinleştir""e tıklayın.
		                    |Devam etmek istiyor musunuz?';
		                    |it = 'Tutti le registrazioni tranne quelli creati manualmente saranno aggiornati dal classificatore banche. 
		                    |Al fine di disabilitare gli aggiornamenti automatici per una determinata registrazione, fare clic su ""Attiva modifica"", sul modulo di elemento della banca.
		                    |Continuare?';
		                    |de = 'Alle außer manuell erstellten Datensätze werden vom Bank-Klassifikator aktualisiert.
		                    |Um automatische Updates für einen bestimmten Datensatz zu deaktivieren, klicken Sie im Bankelementformular auf ""Bearbeitung aktivieren"".
		                    |Möchten Sie fortsetzen?'");
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("UpdateFromClassifierEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0 , DialogReturnCode.No);
        Return;
		
	EndIf;
	
	UpdateFromClassifierFragment();
EndProcedure

&AtClient
Procedure UpdateFromClassifierEnd(Result1, AdditionalParameters) Export
    
    Response = Result1;
    If Response = DialogReturnCode.No Then
        
        Return;
        
    EndIf;
    
    
    UpdateFromClassifierFragment();

EndProcedure

&AtClient
Procedure UpdateFromClassifierFragment()
    
    Var FileInfobase, ConnectTimeoutHandler, Result;
    
    FileInfobase = StandardSubsystemsClientCached.ClientRunParameters().FileInfobase;
    Result  = RunOnServer(FileInfobase);
    
    If Not Result.Status = "Completed" Then
        
        // Handler will be connected until the background job is completed
        ConnectTimeoutHandler = Not FileInfobase AND ValueIsFilled(JobID);
        If ConnectTimeoutHandler Then
            TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
            AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
            LongOperationForm = TimeConsumingOperationsClient.OpenTimeConsumingOperationForm(ThisForm, JobID);
        EndIf;
        
    Else
        ImportPreparedDataAtClient(Result.StructureDataClient);
    EndIf;

EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.BatchObjectModification

&AtClient
Procedure ChangeSelected(Command)
	BatchEditObjectsClient.ChangeSelectedItems(Items.List);
EndProcedure

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Query = New Query("SELECT TOP 1 * FROM Catalog.Banks AS Banks WHERE Banks.ManualChanging <> 2");
	QueryExecutionResult = Query.Execute();
	
	BanksHaveBeenUpdatedFromClassifier = Not QueryExecutionResult.IsEmpty();
	
	// StandardSubsystems.BatchObjectModification
	Items.ChangeSelected.Visible = AccessRight("Edit", Metadata.Catalogs.Banks);
	// End StandardSubsystems.BatchObjectModification
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the prompt result about selecting the bank from classifier
//
//
Procedure DetermineBankPickNeedFromClassifier(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		FormParameters = New Structure("ChoiceMode, CloseOnChoice, MultipleChoice", True, True, True);
		OpenForm("Catalog.BankClassifier.ChoiceForm", FormParameters, ThisForm);
		
	ElsIf ClosingResult = DialogReturnCode.No Then
		
		If AdditionalParameters.IsFolder Then
			OpenForm("Catalog.Banks.FolderForm", New Structure("IsFolder",True), ThisObject);
		Else
			OpenForm("Catalog.Banks.ObjectForm");
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If BankClassifierHasItems() Then
	
		Cancel = True;
		
		QuestionText = NStr("en = 'Select the creation option'; ru = 'Выберите вариант создания';pl = 'Wybierz opcję tworzenia';es_ES = 'Seleccionar la opción de creación';es_CO = 'Seleccionar la opción de creación';tr = 'Oluşturma seçeneğini seçin';it = 'Seleziona l''opzione di creazione';de = 'Wählen Sie die Erstellungsoption'");
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("IsFolder", Group);
		NotifyDescription = New NotifyDescription("DetermineBankPickNeedFromClassifier", ThisObject, AdditionalParameters);
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Create from scratch'; ru = 'Создать с нуля';pl = 'Tworzenie od podstaw';es_ES = 'Crear desde cero';es_CO = 'Crear desde cero';tr = 'Sıfırdan oluştur';it = 'Creare da zero';de = 'Von Grund auf neu erstellen'"));
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Select from classifier'; ru = 'Выбрать из классификатора';pl = 'Wybierz z klasyfikatora';es_ES = 'Seleccionar desde el clasificador';es_CO = 'Seleccionar desde el clasificador';tr = 'Sınıflandırıcıdan seç';it = 'Selezionare dal classificatore';de = 'Aus dem Klassifikator wählen'"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		ShowQueryBox(NotifyDescription, QuestionText, Buttons, , DialogReturnCode.No, Nstr("en = 'Creation option'; ru = 'Вариант создания';pl = 'Opcja tworzenia';es_ES = 'Opción de creación';es_CO = 'Opción de creación';tr = 'Oluşturma seçeneği';it = 'Opzione di creazione';de = 'Erstellungsoption'"));
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
