#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		FilterItem = Filter.Find("Object");
		If FilterItem <> Undefined Then
			ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
			SetPrivilegedMode(True);
			ModuleObjectVersioning.WriteObjectVersion(FilterItem.Value);
			SetPrivilegedMode(False);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf