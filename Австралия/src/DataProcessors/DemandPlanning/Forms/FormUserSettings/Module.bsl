#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("PostOrders", PostOrders);
	Parameters.Property("SetOrderStatusInProgress", SetOrderStatusInProgress);
	Parameters.Property("UseGroupProductsBySupplier", UseGroupProductsBySupplier);
	Parameters.Property("UseGroupProductsBySubcontractor", UseGroupProductsBySubcontractor);
	
	If Parameters.Property("ShowGroupProductsBySubcontractor") Then
		CommonClientServer.SetFormItemProperty(
			Items,
			"GroupSubcontractorOrders",
			"Visible",
			Parameters.ShowGroupProductsBySubcontractor);
	EndIf;
	
	Items.GroupProductionOrders.Visible = Not Constants.DriveTrade.Get();
	
	// begin Drive.FullVersion
	UseProductionSubsystem = GetFunctionalOption("UseProductionSubsystem");
	UseProductionPlanning = GetFunctionalOption("UseProductionPlanning");
	
	If Items.GroupProductionOrders.Visible Then
		Items.GroupProductionOrders.Visible = UseProductionSubsystem;
		Items.IncludeInProductionPlanning.Enabled = UseProductionPlanning;
	EndIf;
	
	If UseProductionSubsystem And UseProductionPlanning Then
		Parameters.Property("IncludeInProductionPlanning", IncludeInProductionPlanning);
	Else
		IncludeInProductionPlanning = False;
	EndIf;
	// end Drive.FullVersion
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SaveClose(Command)
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("UseGroupProductsBySupplier", UseGroupProductsBySupplier);
	SettingsStructure.Insert("PostOrders", PostOrders);
	SettingsStructure.Insert("SetOrderStatusInProgress", SetOrderStatusInProgress);
	SettingsStructure.Insert("UseGroupProductsBySubcontractor", UseGroupProductsBySubcontractor);

	// begin Drive.FullVersion
	SettingsStructure.Insert("IncludeInProductionPlanning", IncludeInProductionPlanning);
	// end Drive.FullVersion
	
	Close(SettingsStructure);
	
EndProcedure

#EndRegion