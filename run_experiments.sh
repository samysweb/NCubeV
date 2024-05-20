echo "Running all experiments -- log files and results wil be in the respective experiment directories"
echo "BEWARE: Before running this you need to build NCubeV"
echo "BEWARE: This will take approx. 2 days!"
./experiments/acas/run.sh
./experiments/acc/run.sh
./experiments/zeppelin/run.sh