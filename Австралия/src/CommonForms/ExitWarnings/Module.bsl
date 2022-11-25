
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
		
	varKey = "";
	For Each Warning In Parameters.Warnings Do
		varKey = varKey + Warning.ActionIfFlagSet.Form + Warning.ActionOnClickHyperlink.Form;
	EndDo;
	
	WindowOptionsKey = "ExitWarnings" + Common.CheckSumString(varKey);
	
	InitializeItemsInForm(Parameters.Warnings);
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_HyperlinkClick(Item)
	ItemName = Item.Name;
	
	For Each QuestionRow In ItemsAndParametersMapArray Do
		QuestionParameters = New Structure("Name, Form, FormParameters");
		
		FillPropertyValues(QuestionParameters, QuestionRow.Value);
		If ItemName = QuestionParameters.Name Then 
			
			If QuestionParameters.Form <> Undefined Then
				OpenForm(QuestionParameters.Form, QuestionParameters.FormParameters, ThisObject);
			EndIf;
			
			Break;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient 
Procedure Attachable_CheckBoxOnChange(Item)
	
	ItemName      = Item.Name;
	FoundItem = Items.Find(ItemName);
	
	If FoundItem = Undefined Then 
		Return;
	EndIf;
	
	ItemValue = ThisObject[ItemName];
	If TypeOf(ItemValue) <> Type("Boolean") Then
		Return;
	EndIf;

	ArrayID = TaskArrayIDByName(ItemName);
	If ArrayID = Undefined Then 
		Return;
	EndIf;
	
	ArrayElement = TasksToExecuteOnCloseArray.FindByID(ArrayID);
	
	Usage = Undefined;
	If ArrayElement.Value.Property("Use", Usage) Then 
		If TypeOf(Usage) = Type("Boolean") Then 
			ArrayElement.Value.Use = ItemValue;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExitApplication(Command)
	
	ExecuteTasksOnClose();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close(True);
	
EndProcedure

#EndRegion

#Region Private

// Creates form items based on questions passed to a user.
//
// Parameters:
//     Questions - Array - structures containing the question value parameters.
//                        See StandardSubsystems.Core.BeforeExit. 
//
&AtServer
Procedure InitializeItemsInForm(Val Warnings)
	
	// Adding the default values that might be not specified.
	WarningTable = StructureArrayIntoValueTable(Warnings);
	
	For Each CurrentWarning In WarningTable Do 
		
		// Adding the item to the form only if either a flag text or a hyperlink text is specified, but not both at the same time.
		RefRequired = Not IsBlankString(CurrentWarning.HyperlinkText);
		FlagRequired   = Not IsBlankString(CurrentWarning.CheckBoxText);
		
		If RefRequired AND FlagRequired Then
			Continue;
			
		ElsIf RefRequired Then
			CreateHyperlinkInForm(CurrentWarning);
			
		ElsIf FlagRequired Then
			CreateCheckBoxInForm(CurrentWarning);
			
		EndIf;
		
	EndDo;
	
	// Footer.
	LabelText = NStr("ru = 'Завершить работу с программой?'; en = 'Do you want to exit the application?'; pl = 'Czy chcesz zamknąć aplikację?';es_ES = '¿Quiere salir de la aplicación?';es_CO = '¿Quiere salir de la aplicación?';tr = 'Uygulamadan çıkmak istiyor musunuz?';it = 'Terminare il lavoro con il programma?';de = 'Möchten Sie die Anwendung beenden?'");
	
	LabelName    = FindLabelNameInForm("QuestionLabel");
	LabelGroup = GenerateFormItemGroup();
	
	InformationTextItem = Items.Add(LabelName, Type("FormDecoration"), LabelGroup);
	InformationTextItem.VerticalAlign = ItemVerticalAlign.Bottom;
	InformationTextItem.Title             = LabelText;
	InformationTextItem.Height                = 2;
	
EndProcedure

&AtServer
Function StructureArrayIntoValueTable(Val Warnings)
	
	// Generating the table that contains default values.
	WarningTable = New ValueTable;
	WarningColumns = WarningTable.Columns;
	WarningColumns.Add("NoteText");
	WarningColumns.Add("CheckBoxText");
	WarningColumns.Add("ActionIfFlagSet");
	WarningColumns.Add("HyperlinkText");
	WarningColumns.Add("ActionOnClickHyperlink");
	WarningColumns.Add("Priority");
	WarningColumns.Add("OutputSingleWarning");
	WarningColumns.Add("ExtendedToolTip");
	
	SingleWarnings = New Array;
	
	For Each WarningItem In Warnings Do
		TableRow = WarningTable.Add();
		FillPropertyValues(TableRow, WarningItem);
		
		If TableRow.OutputSingleWarning = True Then
			SingleWarnings.Add(TableRow);
		EndIf;
	EndDo;
	
	// Clearing all warnings if at least one warning needs to be cleared (OutputSingleWarning = True).
	If SingleWarnings.Count() > 0 Then
		WarningTable = WarningTable.Copy(SingleWarnings);
	EndIf;
	
	// The higher the priority the higher the position of the warning in the list.
	WarningTable.Sort("Priority DESC");
	
	Return WarningTable;
EndFunction

&AtServer
Function GenerateFormItemGroup()
	
	NameOfGroup = FindLabelNameInForm("GroupOnForm");
	
	Folder = Items.Add(NameOfGroup, Type("FormGroup"), Items.MainGroup);
	Folder.Type = FormGroupType.UsualGroup;
	
	Folder.HorizontalStretch = True;
	Folder.ShowTitle      = False;
	Folder.Representation              = UsualGroupRepresentation.None;
	
	Return Folder; 
	
EndFunction

&AtServer
Procedure CreateHyperlinkInForm(QuestionStructure)
	
	Folder = GenerateFormItemGroup();
	
	If Not IsBlankString(QuestionStructure.NoteText) Then 
		LabelName = FindLabelNameInForm("QuestionLabel");
		LabelType = Type("FormDecoration");
		
		LabelParent = Folder;
		
		InformationTextItem = Items.Add(LabelName, LabelType, LabelParent);
		InformationTextItem.Title = QuestionStructure.NoteText;
	EndIf;
	
	If IsBlankString(QuestionStructure.HyperlinkText) Then
		Return;
	EndIf;
	
	// Generating a hyperlink.
	HyperlinkName = FindLabelNameInForm("QuestionLabel");
	HyperlinkType = Type("FormDecoration");
	
	HyperlinkParent = Folder;

	HyperlinkItem = Items.Add(HyperlinkName, HyperlinkType, HyperlinkParent);
	HyperlinkItem.Hyperlink = True;
	HyperlinkItem.Title   = QuestionStructure.HyperlinkText;
	HyperlinkItem.SetAction("Click", "Attachable_HyperlinkClick");
	
	SetExtendedTooltip(HyperlinkItem, QuestionStructure);
	
	DataProcessorStructure = QuestionStructure.ActionOnClickHyperlink;
	If IsBlankString(DataProcessorStructure.Form) Then
		Return;
	EndIf;
	FormOpenParameters = New Structure;
	FormOpenParameters.Insert("Name", HyperlinkName);
	FormOpenParameters.Insert("Form", DataProcessorStructure.Form);
	
	FormParameters = DataProcessorStructure.FormParameters;
	If FormParameters = Undefined Then 
		FormParameters = New Structure;
	EndIf;
	FormParameters.Insert("ApplicationShutdown", True);
	FormOpenParameters.Insert("FormParameters", FormParameters);
	
	ItemsAndParametersMapArray.Add(FormOpenParameters);
		
EndProcedure

&AtServer
Procedure CreateCheckBoxInForm(QuestionStructure)
	
	DefaultValue = True;
	Folder  = GenerateFormItemGroup();
	
	If Not IsBlankString(QuestionStructure.NoteText) Then
		LabelName = FindLabelNameInForm("QuestionLabel");
		LabelType = Type("FormDecoration");
		
		LabelParent = Folder;
		
		InformationTextItem = Items.Add(LabelName, LabelType, LabelParent);
		InformationTextItem.Title = QuestionStructure.NoteText;
	EndIf;
	
	If IsBlankString(QuestionStructure.CheckBoxText) Then 
		Return;
	EndIf;
	
	// Adding the attribute to the form.
	CheckBoxName = FindLabelNameInForm("QuestionLabel");
	FlagType = Type("FormField");
	
	FlagParent = Folder;
	
	TypesArray = New Array;
	TypesArray.Add(Type("Boolean"));
	Details = New TypeDescription(TypesArray);
	
	AttributesToAdd = New Array;
	NewAttribute = New FormAttribute(CheckBoxName, Details, , CheckBoxName, False);
	AttributesToAdd.Add(NewAttribute);
	ChangeAttributes(AttributesToAdd);
	ThisObject[CheckBoxName] = DefaultValue;
	
	NewFormField = Items.Add(CheckBoxName, FlagType, FlagParent);
	NewFormField.DataPath = CheckBoxName;
	
	NewFormField.TitleLocation = FormItemTitleLocation.Right;
	NewFormField.Title          = QuestionStructure.CheckBoxText;
	NewFormField.Type                = FormFieldType.CheckBoxField;
	
	SetExtendedTooltip(NewFormField, QuestionStructure);
	
	If IsBlankString(QuestionStructure.ActionIfFlagSet.Form) Then
		Return;	
	EndIf;
	
	ActionStructure = QuestionStructure.ActionIfFlagSet;
	
	NewFormField.SetAction("OnChange", "Attachable_CheckBoxOnChange");
	
	FormOpenParameters = New Structure;
	FormOpenParameters.Insert("Name", CheckBoxName);
	FormOpenParameters.Insert("Form", ActionStructure.Form);
	FormOpenParameters.Insert("Use", DefaultValue);
	
	FormParameters = ActionStructure.FormParameters;
	If FormParameters = Undefined Then 
		FormParameters = New Structure;
	EndIf;
	FormParameters.Insert("ApplicationShutdown", True);
	FormOpenParameters.Insert("FormParameters", FormParameters);
	
	TasksToExecuteOnCloseArray.Add(FormOpenParameters);
	
EndProcedure

&AtServer
Procedure SetExtendedTooltip(FormItem, Val DetailsString)
	
	ExtendedTooltipDetails = DetailsString.ExtendedToolTip;
	If ExtendedTooltipDetails = "" Then
		Return;
	EndIf;
	
	If TypeOf(ExtendedTooltipDetails) <> Type("String") Then
		// Setting the extended tooltip.
		FillPropertyValues(FormItem.ExtendedTooltip, ExtendedTooltipDetails);
		FormItem.ToolTipRepresentation = ToolTipRepresentation.Button;
		Return;
	EndIf;
	
	FormItem.ExtendedTooltip.Title = ExtendedTooltipDetails;
	FormItem.ToolTipRepresentation = ToolTipRepresentation.Button;
	
EndProcedure

&AtServer
Function FindLabelNameInForm(ItemTitle)
	Index = 0;
	SearchFlag = True;
	
	While SearchFlag Do 
		RowIndex = String(Format(Index, "NZ=-"));
		RowIndex = StrReplace(RowIndex, "-", "");
		Name = ItemTitle + RowIndex;
		
		FoundItem = Items.Find(Name);
		If FoundItem = Undefined Then 
			Return Name;
		EndIf;
		
		Index = Index + 1;
	EndDo;
EndFunction	

&AtClient
Function TaskArrayIDByName(ItemName)
	For Each ArrayElement In TasksToExecuteOnCloseArray Do
		Description = "";
		If ArrayElement.Value.Property("Name", Description) Then 
			If Not IsBlankString(Description) AND Description = ItemName Then
				Return ArrayElement.GetID();
			EndIf;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

&AtClient
Procedure ExecuteTasksOnClose(Result = Undefined, InitialTaskNumber = Undefined) Export
	
	If InitialTaskNumber = Undefined Then
		InitialTaskNumber = 0;
	EndIf;
	
	For TaskNumber = InitialTaskNumber To TasksToExecuteOnCloseArray.Count() - 1 Do
		
		ArrayElement = TasksToExecuteOnCloseArray[TaskNumber];
		Usage = Undefined;
		If Not ArrayElement.Value.Property("Use", Usage) Then 
			Continue;
		EndIf;
		If TypeOf(Usage) <> Type("Boolean") Then 
			Continue;
		EndIf;
		If Usage <> True Then 
			Continue;
		EndIf;
		
		Form = Undefined;
		If ArrayElement.Value.Property("Form", Form) Then 
			FormParameters = Undefined;
			If ArrayElement.Value.Property("FormParameters", FormParameters) Then 
				Notification = New NotifyDescription("ExecuteTasksOnClose", ThisObject, TaskNumber + 1);
				OpenForm(Form, StructureFromFixedStructure(FormParameters),,,,,Notification, FormWindowOpeningMode.LockOwnerWindow);
				Return;
			EndIf;
		EndIf;
	EndDo;
	
	Close(False);
	
EndProcedure

&AtClient
Function StructureFromFixedStructure(Source)
	
	Result = New Structure;
	
	For Each Item In Source Do
		Result.Insert(Item.Key, Item.Value);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
