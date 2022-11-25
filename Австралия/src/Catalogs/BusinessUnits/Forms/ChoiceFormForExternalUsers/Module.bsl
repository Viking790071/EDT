
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonClientServer.SetDynamicListFilterItem(List, "Ref", Catalogs.BusinessUnits.GoodsInTransit, DataCompositionComparisonType.NotEqual);
	CommonClientServer.SetDynamicListFilterItem(List, "Ref", Catalogs.BusinessUnits.DropShipping, DataCompositionComparisonType.NotEqual);
	CommonClientServer.SetDynamicListFilterItem(List, "DeletionMark", False, DataCompositionComparisonType.Equal);
	CommonClientServer.SetDynamicListFilterItem(List, "StructuralUnitType", Enums.BusinessUnitsTypes.Warehouse, DataCompositionComparisonType.Equal);
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
