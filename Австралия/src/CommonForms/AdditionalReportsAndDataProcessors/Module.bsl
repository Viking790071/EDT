#Region Variables

&AtClient
Var CommandToExecute;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.SectionName)
		AND Parameters.SectionName <> AdditionalReportsAndDataProcessorsClientServer.DesktopID() Then
		SectionRef = Common.MetadataObjectID(Metadata.Subsystems.Find(Parameters.SectionName));
	EndIf;
	
	DataProcessorsKind = AdditionalReportsAndDataProcessors.GetDataProcessorKindByKindStringPresentation(Parameters.Kind);
	If DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling Then
		AreAssignableDataProcessors = True;
		Title = NStr("ru = 'Команды заполнения объектов'; en = 'Commands for object filling'; pl = 'Polecenia wypełnienia obiektów';es_ES = 'Comando de la población del objeto';es_CO = 'Comando de la población del objeto';tr = 'Nesne doldurma komutları';it = 'Comandi per compilazione oggetto';de = 'Befehle zur Objektauffüllung'");
	ElsIf DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
		AreAssignableDataProcessors = True;
		AreReports = True;
		Title = NStr("ru = 'Отчеты'; en = 'Reports'; pl = 'Raporty';es_ES = 'Informes';es_CO = 'Informes';tr = 'Raporlar';it = 'Reports';de = 'Berichte'");
	ElsIf DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		AreAssignableDataProcessors = True;
		Title = NStr("ru = 'Дополнительные печатные формы'; en = 'Additional print forms'; pl = 'Dodatkowe drukarskie formy';es_ES = 'Versiones impresas adicionales';es_CO = 'Versiones impresas adicionales';tr = 'Ek yazdırma formları';it = 'Forme di stampa aggiuntive';de = 'Zusätzliche Druckformen'");
	ElsIf DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.RelatedObjectsCreation Then
		AreAssignableDataProcessors = True;
		Title = NStr("ru = 'Команды создания связанных объектов'; en = 'Commands of related object creation'; pl = 'Polecenia utworzenia obiektów powiązanych';es_ES = 'Comandos para crear objetos vinculados';es_CO = 'Comandos para crear objetos vinculados';tr = 'Bağlantılı nesne oluşturma için komutlar';it = 'Comandi di creazione oggetto collegato';de = 'Befehle für die Erstellung von verknüpften Objekten'");
	ElsIf DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor Then
		AreGlobalDataProcessors = True;
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Дополнительные обработки (%1)'; en = 'Additional data processors (%1)'; pl = 'Dodatkowe procesory danych (%1)';es_ES = 'Procesadores de datos adicionales (%1)';es_CO = 'Procesadores de los datos adicionales (%1)';tr = 'Ek veri işlemcileri (%1)';it = 'Elaborazioni aggiuntive (%1)';de = 'Zusätzliche Datenprozessoren (%1)'"), 
			AdditionalReportsAndDataProcessors.SectionPresentation(SectionRef));
	ElsIf DataProcessorsKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		AreGlobalDataProcessors = True;
		AreReports = True;
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Дополнительные отчеты (%1)'; en = 'Additional reports (%1)'; pl = 'Dodatkowe raporty (%1)';es_ES = 'Informes adicionales (%1)';es_CO = 'Informes adicionales (%1)';tr = 'Ek raporlar (%1)';it = 'Ulteriori report  (%1)';de = 'Zusätzliche Berichte (%1)'"), 
			AdditionalReportsAndDataProcessors.SectionPresentation(SectionRef));
	EndIf;
	
	If Parameters.Property("WindowOpeningMode") Then
		WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	If Parameters.Property("Title") Then
		Title = Parameters.Title;
	EndIf;
	
	If AreAssignableDataProcessors Then
		Items.CustomizeList.Visible = False;
		
		RelatedObjects.LoadValues(Parameters.RelatedObjects.UnloadValues());
		If RelatedObjects.Count() = 0 Then
			Cancel = True;
			Return;
		EndIf;
		
		OwnerInfo = AdditionalReportsAndDataProcessorsCached.AssignedObjectFormParameters(Parameters.FormName);
		ParentMetadata = Metadata.FindByType(TypeOf(RelatedObjects[0].Value));
		If ParentMetadata = Undefined Then
			ParentRef = OwnerInfo.ParentRef;
		Else
			ParentRef = Common.MetadataObjectID(ParentMetadata);
		EndIf;
		If TypeOf(OwnerInfo) = Type("FixedStructure") Then
			IsObjectForm = OwnerInfo.IsObjectForm;
		Else
			IsObjectForm = False;
		EndIf;
	EndIf;
	
	FillDataProcessingTable();
	
	If CommonClientServer.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBarPagesOpenProcessing", "Visible", False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	If SelectedValue = "MyReportsAndDataProcessorsSetupDone" Then
		FillDataProcessingTable();
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersCommandTable

&AtClient
Procedure CommandTableChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	ExecuteByParameters();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RunDataProcessor(Command)
	
	ExecuteByParameters()
	
EndProcedure

&AtClient
Procedure CustomizeList(Command)
	FormParameters = New Structure("DataProcessorsKind, SectionRef");
	FillPropertyValues(FormParameters, ThisObject);
	OpenForm("CommonForm.MyReportsAndDataProcessorsSettings", FormParameters, ThisObject, False);
EndProcedure

&AtClient
Procedure CancelDataProcessorExecution(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillDataProcessingTable()
	CommandTypes = New Array;
	CommandTypes.Add(Enums.AdditionalDataProcessorsCallMethods.ClientMethodCall);
	CommandTypes.Add(Enums.AdditionalDataProcessorsCallMethods.ServerMethodCall);
	CommandTypes.Add(Enums.AdditionalDataProcessorsCallMethods.OpeningForm);
	CommandTypes.Add(Enums.AdditionalDataProcessorsCallMethods.ScenarioInSafeMode);
	
	Query = AdditionalReportsAndDataProcessors.NewQueryByAvailableCommands(DataProcessorsKind, ?(AreGlobalDataProcessors, SectionRef, ParentRef), IsObjectForm, CommandTypes);
	ResultTable = Query.Execute().Unload();
	CommandsTable.Load(ResultTable);
EndProcedure

&AtClient
Procedure ExecuteByParameters()
	DataProcessorData = Items.CommandsTable.CurrentData;
	If DataProcessorData = Undefined Then
		Return;
	EndIf;
	
	CommandToExecute = New Structure(
		"Ref, Presentation, 
		|ID, StartupOption, ShowNotification, 
		|Modifier, RelatedObjects, IsReport, Kind");
	FillPropertyValues(CommandToExecute, DataProcessorData);
	If NOT AreGlobalDataProcessors Then
		CommandToExecute.RelatedObjects = RelatedObjects.UnloadValues();
	EndIf;
	CommandToExecute.IsReport = AreReports;
	CommandToExecute.Kind = DataProcessorsKind;
	
	If DataProcessorData.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.OpeningForm") Then
		
		AdditionalReportsAndDataProcessorsClient.OpenDataProcessorForm(CommandToExecute, FormOwner, CommandToExecute.RelatedObjects);
		Close();
		
	ElsIf DataProcessorData.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ClientMethodCall") Then
		
		AdditionalReportsAndDataProcessorsClient.ExecuteDataProcessorClientMethod(CommandToExecute, FormOwner, CommandToExecute.RelatedObjects);
		Close();
		
	ElsIf DataProcessorsKind = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.PrintForm")
		AND DataProcessorData.Modifier = "PrintMXL" Then
		
		AdditionalReportsAndDataProcessorsClient.ExecutePrintFormOpening(CommandToExecute, FormOwner, CommandToExecute.RelatedObjects);
		Close();
		
	ElsIf DataProcessorData.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ServerMethodCall")
		Or DataProcessorData.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ScenarioInSafeMode") Then
		
		// Changing form items
		Items.ExplainingDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Выполняется команда ""%1""...'; en = 'Executing command: ""%1""...'; pl = 'Wykonywanie polecenia ""%1""...';es_ES = 'Ejecutando el comando ""%1""...';es_CO = 'Ejecutando el comando ""%1""...';tr = '""%1"" komutu yürütülüyor...';it = 'Eseguendo comando: ""%1""...';de = 'Ausführen des Befehls ""%1""...'"),
			DataProcessorData.Presentation);
		Items.Pages.CurrentPage = Items.DataProcessorExecutionPage;
		Items.CustomizeList.Visible = False;
		Items.RunDataProcessor.Visible = False;
		
		// Delaying the server call until the form state becomes consistent.
		AttachIdleHandler("ExecuteDataProcessorServerMethod", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDataProcessorServerMethod()
	
	Job = RunBackgroundJob(CommandToExecute, UUID);
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
	
	Handler = New NotifyDescription("RunDataProcessorServerMethodCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(Job, Handler, WaitSettings);
	
EndProcedure

&AtServerNoContext
Function RunBackgroundJob(Val CommandToExecute, Val UUID)
	MethodName = "AdditionalReportsAndDataProcessors.ExecuteCommand";
	
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Доп. отчеты и обработки: Выполнение команды ""%1""'; en = 'Additional reports and data processors: executing the ""%1"" command'; pl = 'Dodatkowe raporty i server method: Wykonywanie polecenia ""%1""';es_ES = 'Informes adicionales y procesamientos: Realización de comandos ""%1""';es_CO = 'Informes adicionales y procesamientos: Realización de comandos ""%1""';tr = 'Ek raporlar ve veri işlemcileri: ""%1"" komutu yürütülüyor';it = 'Report aggiuntivi ed elaboratori dati: eseguendo il comando ""%1""';de = 'Zusätzliche Berichte und Verarbeitung: Ausführung des Befehls ""%1""'"),
		CommandToExecute.Presentation);
	
	MethodParameters = New Structure("AdditionalDataProcessorRef, CommandID, RelatedObjects");
	MethodParameters.AdditionalDataProcessorRef = CommandToExecute.Ref;
	MethodParameters.CommandID          = CommandToExecute.ID;
	MethodParameters.RelatedObjects             = CommandToExecute.RelatedObjects;
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, MethodParameters, StartSettings);
EndFunction

&AtClient
Procedure RunDataProcessorServerMethodCompletion(Job, AdditionalParameters) Export
	If Job.Status = "Completed" Then
		// Showing a pop-up notification and closing this form.
		If CommandToExecute.ShowNotification Then
			ShowUserNotification(
				NStr("ru = 'Команда выполнена'; en = 'Command executed'; pl = 'Polecenie wykonane';es_ES = 'Comando ejecutado';es_CO = 'Comando ejecutado';tr = 'Komut yapıldı';it = 'Comando eseguito';de = 'Befehl ausgeführt'"),
				,
				CommandToExecute.Presentation);
		EndIf;
		If IsOpen() Then
			Close();
		EndIf;
		// Refreshing owner form.
		If IsObjectForm Then
			Try
				FormOwner.Read();
			Except
				// No action required.
			EndTry;
		EndIf;
		// Notifying other forms.
		ExecutionResult = GetFromTempStorage(Job.ResultAddress);
		NotifyForms = CommonClientServer.StructureProperty(ExecutionResult, "NotifyForms");
		If NotifyForms <> Undefined Then
			StandardSubsystemsClient.NotifyFormsAboutChange(NotifyForms);
		EndIf;
	Else
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Команда ""%1"" не выполнена:'; en = 'The ""%1"" command is not executed:'; pl = 'Polecenie ""%1"" nie zostało wykonane:';es_ES = 'Comando ""%1"" no ejecutado:';es_CO = 'Comando ""%1"" no ejecutado:';tr = '""%1"" komutu yürütülmedi:';it = 'Il comando ""%1"" non è stato eseguito:';de = 'Der Befehl ""%1"" wird nicht ausgeführt:'"),
			CommandToExecute.Presentation);
		If IsOpen() Then
			Close();
		EndIf;
		Raise Text + Chars.LF + Job.BriefErrorPresentation;
	EndIf;
EndProcedure

#EndRegion