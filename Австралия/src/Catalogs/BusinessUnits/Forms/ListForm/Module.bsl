
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return; // Return if the form for analysis is received..
	EndIf;
	
	If Parameters.Property("DoNotCheckCompanyInBusinessUnit") And Parameters.DoNotCheckCompanyInBusinessUnit = True Then
		Parameters.Filter.Delete("Company");
	EndIf;
	
	MainDepartment	= DriveReUse.GetValueOfSetting("MainDepartment");
	MainWarehouse	= DriveReUse.GetValueOfSetting("MainWarehouse");
	
	MainBusinessUnits = New Array;
	MainBusinessUnits.Add(MainDepartment);
	MainBusinessUnits.Add(MainWarehouse);
	List.Parameters.SetParameterValue("MainBusinessUnits", MainBusinessUnits);
	
	ShowDepartment	= True;
	ShowWarehouse	= True;
	
	If Parameters.Filter.Property("StructuralUnitType") Then
		
		ShowDepartment	= False;
		ShowWarehouse	= False;
		
		If TypeOf(Parameters.Filter.StructuralUnitType) = Type("EnumRef.BusinessUnitsTypes") Then
			
			ShowDepartment	= Parameters.Filter.StructuralUnitType = Enums.BusinessUnitsTypes.Department;
			ShowWarehouse	= Not ShowDepartment;
			
		Else
			
			For Each ArrayItem In Parameters.Filter.StructuralUnitType Do
				If ArrayItem = Enums.BusinessUnitsTypes.Department Then
					ShowDepartment = True;
				Else
					ShowWarehouse = True;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndIf;
	
	Title = "";
	If ShowWarehouse AND ShowDepartment Then
		Title = NStr("en = 'Business units'; ru = 'Структурные единицы';pl = 'Jednostki biznesowe';es_ES = 'Unidades empresariales';es_CO = 'Unidades de negocio';tr = 'Departmanlar';it = 'Business unit';de = 'Abteilungen'");
	ElsIf ShowWarehouse Then
		Title = NStr("en = 'Warehouses'; ru = 'Склады';pl = 'Magazyny';es_ES = 'Almacenes';es_CO = 'Almacenes';tr = 'Ambarlar';it = 'Magazzini';de = 'Lager'");
	ElsIf ShowDepartment Then
		Title = NStr("en = 'Departments'; ru = 'Подразделения';pl = 'Działy';es_ES = 'Departamentos';es_CO = 'Departamentos';tr = 'Bölümler';it = 'Reparti';de = 'Abteilungen'");
	EndIf;
	
	Items.FormUseAsMainDepartment.Visible	= ShowDepartment;
	Items.FormUseAsMainWarehouse.Visible	= ShowWarehouse;
	
	Items.Company.Visible = GetFunctionalOption("UseDataSynchronization");
	
	// Exclusion of special predefined warehouse GoodsInTransit from ListForm
	DataFilterItem = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Ref");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	DataFilterItem.RightValue = Catalogs.BusinessUnits.GoodsInTransit;
	DataFilterItem.Use = True;
	
	// Exclusion of special predefined warehouse DropShipping from ListForm
	DataFilterItem = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Ref");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	DataFilterItem.RightValue = Catalogs.BusinessUnits.DropShipping;
	DataFilterItem.Use = True;
	
	TypesHierarchy = False;
	If Not (ShowWarehouse AND ShowDepartment) Then
		TypesHierarchy = CheckTypesHierarchy();
	EndIf;
	
	// Set form settings for the case of the opening of the choice mode
	Items.List.ChoiceMode		= Parameters.ChoiceMode;
	Items.List.MultipleChoice	= ?(Parameters.CloseOnChoice = Undefined, False, Not Parameters.CloseOnChoice);
	If Parameters.ChoiceMode Then
		PurposeUseKey = PurposeUseKey + "ChoicePick";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	Else
		PurposeUseKey = PurposeUseKey + "List";
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If TypesHierarchy Then
		Items.List.Representation = TableRepresentation.List;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	CurrentData = Items.List.CurrentData;
	
	If TypeOf(Items.List.CurrentRow) <> Type("DynamicListGroupRow")
		And CurrentData <> Undefined Then
		
		IsDepartment = (CurrentData.StructuralUnitType = PredefinedValue("Enum.BusinessUnitsTypes.Department"));
		Items.FormUseAsMainDepartment.Enabled	= Not CurrentData.IsMain And IsDepartment;
		Items.FormUseAsMainWarehouse.Enabled	= Not CurrentData.IsMain And Not IsDepartment;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure UseAsMainDepartment(Command)
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicListGroupRow")
		Or Items.List.CurrentData = Undefined
		Or Items.List.CurrentData.IsMain
		Or Items.List.CurrentData.StructuralUnitType <> PredefinedValue("Enum.BusinessUnitsTypes.Department") Then
		
		Return;
	EndIf;
	
	SetMainStructuralUnit(Items.List.CurrentData.Ref, "MainDepartment");
	Items.FormUseAsMainDepartment.Enabled	= Not Items.List.CurrentData.IsMain;
	
EndProcedure

&AtClient
Procedure UseAsMainWarehouse(Command)
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicListGroupRow")
		Or Items.List.CurrentData = Undefined
		Or Items.List.CurrentData.IsMain
		Or Items.List.CurrentData.StructuralUnitType = PredefinedValue("Enum.BusinessUnitsTypes.Department") Then
		
		Return;
	EndIf;
	
	SetMainStructuralUnit(Items.List.CurrentData.Ref, "MainWarehouse");
	Items.FormUseAsMainWarehouse.Enabled	= Not Items.List.CurrentData.IsMain;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetMainStructuralUnit(Val NewMainStructuralUnit, SettingName)
	
	DriveServer.SetUserSetting(NewMainStructuralUnit, SettingName);
	
	ThisObject[SettingName] = NewMainStructuralUnit;
	
	MainBusinessUnits = New Array;
	MainBusinessUnits.Add(MainDepartment);
	MainBusinessUnits.Add(MainWarehouse);
	List.Parameters.SetParameterValue("MainBusinessUnits", MainBusinessUnits);
	
EndProcedure

&AtServer
Function CheckTypesHierarchy()
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	BusinessUnits.Ref
	|FROM
	|	Catalog.BusinessUnits AS BusinessUnits
	|WHERE
	|	BusinessUnits.Parent <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|	AND BusinessUnits.StructuralUnitType <> BusinessUnits.Parent.StructuralUnitType";
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

&AtClient
Procedure Create(Command)
	
	StructureParameters = New Structure;
	
	If ShowWarehouse AND ShowDepartment Then
		StructureParameters.Insert("FilterUnitType", "BusinessUnits");
	ElsIf ShowWarehouse Then
		StructureParameters.Insert("FilterUnitType", "Warehouse");
	ElsIf ShowDepartment Then
		StructureParameters.Insert("FilterUnitType", "Department");
		StructureParameters.Insert("StructuralUnitType", PredefinedValue("Enum.BusinessUnitsTypes.Department"));
	EndIf;
	
	OpenForm("Catalog.BusinessUnits.ObjectForm", StructureParameters);
	
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion
