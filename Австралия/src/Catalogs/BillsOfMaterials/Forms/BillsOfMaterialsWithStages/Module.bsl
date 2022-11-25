#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("BillOfMaterials", BillOfMaterials);
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'BOM explosion: %1'; ru = 'Разбивка спецификации: %1';pl = 'Podział specyfikacji materiałowej: %1';es_ES = 'Explosión de BOM: %1';es_CO = 'Explosión de BOM: %1';tr = 'Ürün reçetesi açılımı: %1';it = 'Esplosione distinta base: %1';de = 'Stücklistenauflösung: %1'"),
		BillOfMaterials);
		
	Settings = GetUserSettings();
	GenerateOption = Common.CommonSettingsStorageLoad(Settings.ObjectKey, Settings.SettingsKey, Settings.DefaultGenerateOption, , Settings.UserName);
	GenerateOptionOnOpen = GenerateOption;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillTree();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If GenerateOptionOnOpen <> GenerateOption Then
		SaveNewSettings();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure GenerateOptionOnChange(Item)
	
	FillTree();
	
EndProcedure

#EndRegion

#Region BOMStructureFormTableItemsEventHandlers

&AtClient
Procedure BOMStructureSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	BOMStructureLine = Items.BOMStructure.CurrentData;
	
	If Not ValueIsFilled(BOMStructureLine.Product)
		And (Field.Name = "BOMStructureBOMExplosion" Or Not ValueIsFilled(BOMStructureLine.BillOfMaterials)) Then
		
		ShowValue(, BOMStructureLine.Activity);
		
	ElsIf ValueIsFilled(BOMStructureLine.Product)
		And (Field.Name = "BOMStructureBOMExplosion" Or Not ValueIsFilled(BOMStructureLine.BillOfMaterials)) Then
		
		ShowValue(, BOMStructureLine.Product);
		
	Else
		
		ShowValue(, BOMStructureLine.BillOfMaterials);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExpandAll(Command)
	
	LevelBOMs = BOMStructure.GetItems();
	For Each LevelBOM In LevelBOMs Do
		Items.BOMStructure.Expand(LevelBOM.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure CollapseAll(Command)
	
	CollapseRecursively(BOMStructure.GetItems());
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FillTree()
	
	ExecutionResult = FillTreeOnServer();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.MessageText = NStr("en = 'Generating report.'; ru = 'Отчет формируется.';pl = 'Generowanie raportu.';es_ES = 'Generando el informe.';es_CO = 'Generando el informe.';tr = 'Rapor oluşturuluyor.';it = 'Creazione report.';de = 'Der Bericht wird generiert.'");
	IdleParameters.OutputMessages = True;
	IdleParameters.OutputIdleWindow = True;
	IdleParameters.OutputProgressBar = True;
	
	CompletionNotification = New NotifyDescription("OnCompleteFillInTree", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(ExecutionResult, CompletionNotification, IdleParameters);
	
EndProcedure

&AtClient
Procedure OnCompleteFillInTree(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Completed" Then
		
		FillInTreeAfterBackgroundJob(Result.ResultAddress);
		ExpandAll(Undefined);
		
	ElsIf Result.Status = "Error" Then
		MessageText = StrTemplate(NStr("en = 'Cannot generate report: %1'; ru = 'Не удалось сформировать отчет: %1';pl = 'Nie można się wygenerować raportu: %1';es_ES = 'No se puede generar el informe: %1';es_CO = 'No se puede generar el informe: %1';tr = 'Rapor oluşturulamadı: %1';it = 'Impossibile creare report: %1';de = 'Fehler beim Generieren des Berichts: %1'"), Result.BriefErrorPresentation);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInTreeAfterBackgroundJob(ResultAddress)
	
	Result = GetFromTempStorage(ResultAddress);
	ValueToFormAttribute(Result.Tree, "BOMStructure");
	
EndProcedure

&AtServer
Function FillTreeOnServer()
	
	Tree = FormAttributeToValue("BOMStructure");
	Tree.Rows.Clear();
	
	ProcedureName = "Catalogs.BillsOfMaterials.FillInBOMExplosionTree";
	
	OperationParameters = New Structure;
	OperationParameters.Insert("Tree", Tree);
	OperationParameters.Insert("BillOfMaterials", BillOfMaterials);
	OperationParameters.Insert("ShowOperations", GenerateOption = 0 Or GenerateOption = 2);
	OperationParameters.Insert("ShowComponents", GenerateOption = 0 Or GenerateOption = 1);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Generating report ""Bill of materials explosion.""'; ru = 'Формирование отчета ""Разбивка спецификации"".';pl = 'Generowanie raportu ""Podział specyfikacji materiałowej.""';es_ES = 'Generando informe ""Desglose de la lista de materiales""';es_CO = 'Generando informe ""Desglose de la lista de materiales""';tr = '""Ürün reçetesi açılımı"" raporu oluşturuluyor.';it = 'Creazione report ""Esplosione distinta base.""';de = 'Bericht ""Entwicklung von Stückliste."" wird generiert'");
	
	Return TimeConsumingOperations.ExecuteInBackground(ProcedureName, OperationParameters, ExecutionParameters);
	
EndFunction

&AtClient
Procedure CollapseRecursively(TreeItems)
	
	For Each TreeItems_Item In TreeItems Do
		
		InTreeItems = TreeItems_Item.GetItems();
		If InTreeItems.Count() > 0 Then
			CollapseRecursively(InTreeItems);
		EndIf;
		Items.BOMStructure.Collapse(TreeItems_Item.GetID());
		
	EndDo;
	
EndProcedure

&AtServer
Function GetUserSettings()
	
	Settings = New Structure;
	Settings.Insert("ObjectKey", "BillsOfMaterialsExplosion");
	Settings.Insert("SettingsKey", Settings.ObjectKey + "_GenerateOptionUserChoice");
	Settings.Insert("DefaultGenerateOption", 0);
	Settings.Insert("UserName", UserName());
	
	Return Settings;
	
EndFunction

&AtServer
Procedure SaveNewSettings()
	
	Settings = GetUserSettings();
	Common.CommonSettingsStorageSave(Settings.ObjectKey, Settings.SettingsKey, GenerateOption, , Settings.UserName);
	
EndProcedure

#EndRegion
