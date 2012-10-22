#! /bin/bash

# Volume maker for calculating cost function by changing three parameters for BRAINSFitIGT 
# ------------------------------------------------------------------------------------------------------------------------------------------------
# Concept by Atsushi Yamada PhD, Surgical Navigation and Robotics Laboratory (SNR), Brigham and Women's Hospital and Harvard Medical School
# The script is by Junichi Tokuda PhD, Surgical Navigation and Robotics Laboratory (SNR), Brigham and Women's Hospital and Harvard Medical School 
# ----------------------------------------------------------------------------

echo "====================================================================="
echo "Cost Function Calculater by Changing Three Parameters for BRAINSFitIGT"
echo "Scripted by Atsushi Yamada, PhD, Brigham and Women's Hospital and Harvard Medical School"
echo "====================================================================="

# Procedure
# * Execute a script yamada_make_volume.sh to create deformed images by using ROI Bspline
# * Change condition of if loop in itkRegularStepGradientDescentBaseOptimizer.cxx, l.246
# * make at ./Slicer3-lib/Insight-build/
# * execute this script
# * you can obtain the cost function based on MMI in /CalculationResults/CostFunction-txt
# * execute script to create csv file to collect all data

# Custom file
# 1. genericRegistrationHelper.txx
# add a following line at l.409 of genericRegistrationHelper.txx for both Slicer3
#   std::cout << std::endl << "AY-added in generic2000...txx: m_FinalMetricValue = " << m_FinalMetricValue << std::endl << std::endl;
# For reflecting the edit, you have to update genericRegistrationHelper.h since the source file is not cxx but txx.
# 2. itkRegularStepGradientDescentBaseOptimizer.cxx
# change a line as follows at l.246 for only the latter Slicer3
#   if( m_CurrentStepLength < m_MinimumStepLength )
#   -> if( 1 )


#--------------------------------------------------------------------
# Update History
# 8/22/2012: coding, basic test 
# 9/ 1/2012: coding, basic test
# 9/ 2/2012: combine all three steps
# 10/5/2012: coding to use TRE, 95%HD, and DSC for  assessment of accurucy for nonrigid registration
# 10/10/2012: coding, basic test
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# set three parameters
#--------------------------------------------------------------------
# 1. sample number
#sample=(5000 6000 7000 8000 9000 10000 20000 30000 40000 50000 60000 70000 80000 90000 100000 )
sample=(4000 6000 8000 10000 20000 40000 60000 80000 100000 120000 140000 160000 180000 200000)
#sample=(180000)

# 2. number of histogram bins
# written in the loop of each step

# 3. grid number
# written in the loop of each step
#--------------------------------------------------------------------

echo "----------------------------------------------------------------------------"
echo "STEP 0.0: SET UP VARIABLES"
echo "----------------------------------------------------------------------------"

preFcsv="L-pre.fcsv"
postFcsv="L-post.fcsv"

inputpath=/media/TOSHIBAEXT/IBM3/Materials/
outputPath=/media/TOSHIBAEXT/IBM3/CalculationResults/
slicer_path=/home/CTGuidedAblation/Applicaiton/Slicer-release/Slicer3-build/lib/Slicer3/Plugins
pathForFcsvFile=/home/CTGuidedAblation/LIVER_CASES/CostfunctionCalculation/BrainsFit-CLI-testIBM4/

        
fixedVolume=$inputpath"N4-post-new.nrrd"
movingVolume=$inputpath"N4-pre-new.nrrd"
fixedBinaryVolume=$inputpath"post-MRI-label2.nrrd"
movingBinaryVolume=$inputpath"N4-pre-label.nrrd"
fiducialFile=$pathForFcsvFile$preFcsv

savefilename=TargetRegistrationErrors.csv

declare -i n=1
declare -i i=0

# for metrics
declare -a metrics_data=(0 0)
metricssavefilename=Metrics.csv
metricsResultHead=`echo "numberOfHistogramBins,plineGridSize,numberOfSamples,DSC,HD"`
echo "$metricsResultHead" >>$metricssavefilename


echo "----------------------------------------------------------------------------"
echo "STEP 0.6: CREATE DEFORMED MASK DATA"
echo "STEP 0.7: CALCULATE DSC AND 95%HD"
echo "STEP 0.8: SAVE METRICS"
echo "----------------------------------------------------------------------------"

for numberOfHistogramBins in {40..60}
do
    for splineGridSize in 3 4 5 6
    do
	for numberOfSamples in ${sample[@]}
	do
	    outputVolume=$inputpath"image-$numberOfHistogramBins-$splineGridSize-$numberOfSamples.nrrd"
      deformedGridImage=$outputPath"gridImages/""gridImage-$numberOfHistogramBins-$splineGridSize-$numberOfSamples.nrrd"
      bsplineTransform=$outputPath"transform/""transform-$numberOfHistogramBins-$splineGridSize-$numberOfSamples.mat"
      outtext=$outputPath"txt/""image-$numberOfHistogramBins-$splineGridSize-$numberOfSamples.txt"
      anatomicalFcsv="anatomicalMarkers-$numberOfHistogramBins-$splineGridSize-$numberOfSamples.fcsv"
	    outputFcsv=$outputPath"txt/"$anatomicalFcsv
      
      echo ""  
      echo "STEP0.6: Creating deformed mask data..."

      maskVolume=$inputpath"XXXXXXXXXXXXXXX.nrrd" # precise preprocedural mask data
      postMaskVolume=$inputpath"XXXXXXXXXXXXXXX.nrrd" #precise postprocedural mask data
      deformedMask=$inputpath"mask-$numberOfHistogramBins-$splineGridSize-$numberOfSamples.nrrd"
      outputMetrics=$inputpath"metrics-$numberOfHistogramBins-$splineGridSize-$numberOfSamples.nrrd"
      metricsFcsv="metrics-$numberOfHistogramBins-$splineGridSize-$numberOfSamples.fcsv"
	    outputMetricsFcsv=$outputPath"txt/"$metricsFcsv
      
      #/Users/ayamada/Develop/Slicer36-stable-12092011/Slicer3-build/lib/Slicer3/Plugins/BRAINSResample --inputVolume /Users/ayamada/Slicer3ayamada/FGAJH_vtkMRMLScalarVolumeNodeE.nrrd --referenceVolume /Users/ayamada/Slicer3ayamada/FGAJH_vtkMRMLScalarVolumeNodeB.nrrd --outputVolume /Users/ayamada/Slicer3ayamada/FGAJH_vtkMRMLScalarVolumeNodeG.nrrd --pixelType short --warpTransform /Users/ayamada/Slicer3ayamada/FGAJH_vtkMRMLBSplineTransformNodeB.mat --interpolationMode NearestNeighbor --defaultValue 0 
      $slicer_path/BRAINSResample --inputVolume $maskVolume --referenceVolume $fixedVolume --outputVolume $deformedMask --pixelType short --warpTransform $bsplineTransform --interpolationMode NearestNeighbor --defaultValue 0 

      echo ""  
      echo "STEP0.7: Calculating DSC and 95%HD..."
      #/Volumes/HybridDrive/H-Documents/registration-metric-build/lib/Slicer3/Plugins/RegistrationMetrics /Users/ayamada/Slicer3ayamada/FIDGA_vtkMRMLScalarVolumeNodeD.nrrd /Users/ayamada/Slicer3ayamada/FIDGA_vtkMRMLScalarVolumeNodeD.nrrd /Users/ayamada/Slicer3ayamada/FIDGA_vtkMRMLScalarVolumeNodeF.nrrd 
      $slicer_path/Plugins/RegistrationMetrics $deformedMask $postMaskVolume $outputMetrics $outputMetricsFcsv 

      echo ""  
      echo "STEP0.8: Saving THE result of metrics..."
      echo $outputMetricsFcsv
      while read LINE; do
          # get each field
          metrics_data[0]=`echo ${LINE} | cut -d , -f 2`
          metrics_data[1]=`echo ${LINE} | cut -d , -f 4`
          #execute command
          echo "DSC=${metrics_data[0]}, HD=${metrics_data[1]}"  
      done < $outputFcsv
      
      # write file
      result=`echo "$numberOfHistogramBins,$splineGridSize,$numberOfSamples,${metrics_data[0]},${metrics_data[1]}"`
      echo "Saving data of "$metricssavefilename
      echo "$result" >>$metricssavefilename
      echo "$metricsResultHead"
      echo "$result"

      #
      
    done
    done
done



