
#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FOMultipleCompaniesAccounting = GetFunctionalOption("UseSeveralCompanies");
	Items.LabelCompany.Title = ?(FOMultipleCompaniesAccounting, NStr("en = 'Companies'; ru = 'Организации';pl = 'Firmy';es_ES = 'Empresas';es_CO = 'Empresas';tr = 'İş yerleri';it = 'Aziende';de = 'Firmen'"), NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"));
	
	FOAccountingBySeveralWarehouses = GetFunctionalOption("UseSeveralWarehouses");
	Items.LabelWarehouses.Title = ?(FOAccountingBySeveralWarehouses, NStr("en = 'Warehouses'; ru = 'Склады';pl = 'Magazyny';es_ES = 'Almacenes';es_CO = 'Almacenes';tr = 'Ambarlar';it = 'Magazzini';de = 'Lagerhäuser'"), NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
	
	FOAccountingBySeveralDepartments = GetFunctionalOption("UseSeveralDepartments");
	Items.LabelDepartments.Title = ?(FOAccountingBySeveralDepartments, NStr("en = 'Departments'; ru = 'Подразделения';pl = 'Działy';es_ES = 'Departamentos';es_CO = 'Departamentos';tr = 'Bölümler';it = 'Reparti';de = 'Abteilungen'"), NStr("en = 'Department'; ru = 'Подразделение';pl = 'Dział';es_ES = 'Departamento';es_CO = 'Departamento';tr = 'Bölüm';it = 'Reparto';de = 'Abteilung'"));
	
	FOAccountingBySeveralLinesOfBusiness = GetFunctionalOption("AccountingBySeveralLinesOfBusiness");
	Items.LabelLinesOfBusiness.Title = ?(FOAccountingBySeveralLinesOfBusiness, NStr("en = 'Lines of business'; ru = 'Направления деятельности';pl = 'Rodzaje działalności';es_ES = 'Líneas de negocio';es_CO = 'Líneas de negocio';tr = 'İş kolları';it = 'Linee di business';de = 'Geschäftsfelder'"), NStr("en = 'Line of business'; ru = 'Направление деятельности';pl = 'Rodzaj działalności';es_ES = 'Dirección de negocio';es_CO = 'Dirección de negocio';tr = 'İş kolu';it = 'Linea di business';de = 'Geschäftsbereich'"));
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ConstantsSet" Then 
		
		If Source = "UseSeveralCompanies" Then
			
			FOMultipleCompaniesAccounting = GetFOServer("UseSeveralCompanies");
			Items.LabelCompany.Title = ?(FOMultipleCompaniesAccounting, NStr("en = 'Companies'; ru = 'Организации';pl = 'Firmy';es_ES = 'Empresas';es_CO = 'Empresas';tr = 'İş yerleri';it = 'Aziende';de = 'Firmen'"), NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"));
			
		ElsIf Source = "UseSeveralWarehouses" Then
			
			FOAccountingBySeveralWarehouses = GetFOServer("UseSeveralWarehouses");
			Items.LabelWarehouses.Title = ?(FOAccountingBySeveralWarehouses, NStr("en = 'Warehouses'; ru = 'Склады';pl = 'Magazyny';es_ES = 'Almacenes';es_CO = 'Almacenes';tr = 'Ambarlar';it = 'Magazzini';de = 'Lagerhäuser'"), NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
			
		ElsIf Source = "UseSeveralDepartments" Then
			
			FOAccountingBySeveralDepartments = GetFOServer("UseSeveralDepartments");
			Items.LabelDepartments.Title = ?(FOAccountingBySeveralDepartments, NStr("en = 'Departments'; ru = 'Подразделения';pl = 'Działy';es_ES = 'Departamentos';es_CO = 'Departamentos';tr = 'Bölümler';it = 'Reparti';de = 'Abteilungen'"), NStr("en = 'Department'; ru = 'Подразделение';pl = 'Dział';es_ES = 'Departamento';es_CO = 'Departamento';tr = 'Bölüm';it = 'Reparto';de = 'Abteilung'"));
			
		ElsIf Source = "UseSeveralLinesOfBusiness" Then
			
			FOAccountingBySeveralLinesOfBusiness = GetFOServer("AccountingBySeveralLinesOfBusiness");
			Items.LabelLinesOfBusiness.Title = ?(FOAccountingBySeveralLinesOfBusiness, NStr("en = 'Lines of business'; ru = 'Направления деятельности';pl = 'Rodzaje działalności';es_ES = 'Líneas de negocio';es_CO = 'Líneas de negocio';tr = 'İş kolları';it = 'Linee di business';de = 'Geschäftsfelder'"), NStr("en = 'Line of business'; ru = 'Направление деятельности';pl = 'Rodzaj działalności';es_ES = 'Dirección de negocio';es_CO = 'Dirección de negocio';tr = 'İş kolu';it = 'Linea di business';de = 'Geschäftsbereich'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure LabelCompaniesClick(Item)
	
	If FOMultipleCompaniesAccounting Then
		OpenForm("Catalog.Companies.ListForm");
	Else
		ParemeterCompany = New Structure("Key", PredefinedValue("Catalog.Companies.MainCompany"));
		OpenForm("Catalog.Companies.ObjectForm", ParemeterCompany);
	EndIf;
	
EndProcedure

// Procedure - command handler CatalogWarehouses.
//
&AtClient
Procedure LableWarehousesClick(Item)
	
	If FOAccountingBySeveralWarehouses Then
		
		FilterArray = New Array;
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.Warehouse"));
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.Retail"));
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.RetailEarningAccounting"));
		
		FilterStructure = New Structure("StructuralUnitType", FilterArray);
		
		OpenForm("Catalog.BusinessUnits.ListForm", New Structure("Filter", FilterStructure));
		
	Else
		
		ParameterWarehouse = New Structure("Key", PredefinedValue("Catalog.BusinessUnits.MainWarehouse"));
		OpenForm("Catalog.BusinessUnits.ObjectForm", ParameterWarehouse);
		
	EndIf;
	
EndProcedure

// Procedure - command handler CatalogDepartments.
//
&AtClient
Procedure LabelDepartmentClick(Item)
	
	If FOAccountingBySeveralDepartments Then
		
		FilterStructure = New Structure("StructuralUnitType", PredefinedValue("Enum.BusinessUnitsTypes.Department"));
		
		OpenForm("Catalog.BusinessUnits.ListForm", New Structure("Filter", FilterStructure));
	
	Else
		
		ParameterDepartment = New Structure("Key", PredefinedValue("Catalog.BusinessUnits.MainDepartment"));
		OpenForm("Catalog.BusinessUnits.ObjectForm", ParameterDepartment);
		
	EndIf;
	
EndProcedure

// Procedure - command handler CatalogLinesOfBusiness.
//
&AtClient
Procedure LableLinesOfBusinessClick(Item)
	
	If FOAccountingBySeveralLinesOfBusiness Then
		OpenForm("Catalog.LinesOfBusiness.ListForm");
	Else
		
		ParameterBusinessLine = New Structure("Key", PredefinedValue("Catalog.LinesOfBusiness.MainLine"));
		OpenForm("Catalog.LinesOfBusiness.ObjectForm", ParameterBusinessLine);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
	
&AtServerNoContext
Function GetFOServer(NameFunctionalOption)
	
	Return GetFunctionalOption(NameFunctionalOption);
	
EndFunction

#EndRegion
